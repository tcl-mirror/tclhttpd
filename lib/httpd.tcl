# httpd.tcl
#
# HTTP 1.0 protocol stack, plus connection keep-alive and 1.1 subset.
# This accepts connections and calls out to Url_Dispatch once a request
# has been recieved.  There are several utilities for returning
# different errors, redirects, challenges, files, and data.
#
# For binary data transfer this uses unsupported0 or fcopy.
# Tcl8.0a2 was the last release with unsupported0.
# Note that Tcl8.0b1 has a bug in fcopy where if an error occurs then
# bgerror is called instead of the command callback to fcopy.  This
# causes file descriptor leaks, so don't use 8.0b1 for real servers.
#
# Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) httpd.tcl 1.16 97/07/12 14:29:54

package provide httpd 1.1

# initialize all the global data

# Location of this package
set Httpd(library) [file dirname [info script]]

# HTTP/1.0 error codes (the ones we use)
array set Httpd_Errors {
    200 {Data follows}
    204 {No Content}
    302 {Found}
    400 {Bad Request}
    401 {Authorization Required}
    403 {Permission denied}
    404 {Not Found}
    408 {Request Timeout}
    411 {Length Required}
    419 {Expectation Failed}
    500 {Server Internal Error}
    503 {Service Unavailable}
    504 {Service Temporarily Unavailable}
}
# Environment variables that are extracted from the mime header
# and passed to the CGI script.  the values are keys into the
# per-connection state array (i.e. "data")

array set Httpd_EnvMap {
    CONTENT_LENGTH	mime,content-length
    CONTENT_TYPE	mime,content-type
    HTTP_ACCEPT		mime,accept
    HTTP_AUTHORIZATION	mime,authorization
    HTTP_FROM		mime,from
    HTTP_REFERER	mime,referer
    HTTP_USER_AGENT	mime,user-agent
    QUERY_STRING	query
    REQUEST_METHOD	proto
    HTTP_COOKIE         mime,cookie
}

# Httpd_Init
# Initialize the httpd module.  Call this early.
# Httpd is a global array containing the global server state
# bufsize:	Chunk size for copies
# fcopy:	True if fcopy is being used.
# initialized:	True after server started.
# ipaddr:	Non-default ipaddr for the server (for multiple interfaces)
# library:	a directory containing the tcl scripts.
# port:		The port this server is serving
# listen:	the main listening socket id
# server:	The server ID for the HTTP protocol.
# shutdown:	A list of Tcl callbacks made when the server shuts down
# sockblock:	blocking mode value for sockets (normally this should be 0)
# timeout1:	Time before the server closes a kept-alive socket (msecs)
# timeout2:	Time before the server kills an in-progress transaction.  (msecs)
# version:	The version number.
# maxused:	Max number of transactions per socket (keep alive)

proc Httpd_Init {} {
    global Httpd
    array set Httpd {
	timeout1	120000
	timeout2	120000
	server		"Tcl-Webserver/"
	initialized 	1
	shutdown	""
	sockblock	0
	bufsize		16384
	maxused		25
    }
    Httpd_Version
    append Httpd(server) $Httpd(version)
    if {[info commands "unsupported0"] == "unsupported0"} {
	rename unsupported0 copychannel
    }
    if {[info commands "copychannel"] == "copychannel"} {
	set Httpd(fcopy) 0
    } else {
	set Httpd(fcopy) 1
    }
    # We always have the counter module and mimetyes
    Counter_Init
    Mtype_ReadTypes [file join $Httpd(library) mime.types]
}

# Httpd_Server
# start the server by listening for connections on the desired port.
# This may be re-run to re-start the server.  Call this late,
# after Httpd_Init and the init calls for the other modules.
# port: The TCP listening port number
# name: the qualified host name returned in the Host field.  Defaults
#	to [info hostname]
# ipaddr: non-default interface address.  Otherwise IP_ADDR_ANY is used
#	so the server can accept connections from any interface.
#
# This sets up a callback to HttpdAccept for new connections.

proc Httpd_Server {{port 80} {name {}} {ipaddr {}}} {
    global Httpd

    if {![info exists Httpd(initialized)]} {
	Httpd_Init
    }
    catch {close $Httpd(listen)}
    set Httpd(name) $name
    set Httpd(ipaddr) $ipaddr
    set Httpd(port) $port
    if {[string length $name] == 0} {
	set Httpd(name) [info hostname]
    }
    set cmd [list socket -server HttpdAccept]
    if {[string length $ipaddr] != 0} {
	lappend cmd -myaddr $ipaddr
    }
    lappend cmd $port
    if {[catch $cmd Httpd(listen)]} {
	return -code error "$Httpd(name):$port $Httpd(listen)"
    }
    Counter_Reset accepts
}

# Kill the server gracefully

proc Httpd_Shutdown {} {
    global Httpd
    set ok 1
    foreach handler $Httpd(shutdown) {
	if [catch {eval $handler} err] {
	    Log "" "Shutdown: $handler" $err
	    set ok 0
	}
    }
    Log {} Shutdown
    catch {close $Httpd(listen)}
    return $ok
}

# Register a Tcl command to be called by Httpd_Shutdown

proc Httpd_RegisterShutdown {cmd} {
    global Httpd
    if {[lsearch $Httpd(shutdown) $cmd] < 0} {
	lappend Httpd(shutdown) $cmd
    }
}

# Accept a new connection from the server and set up a handler, HttpdRead,
# to read the request from the client.  The per-connection state is
# kept in Httpd$sock, (e.g., Httpdsock6), and upvar is used to
# create a local "data" alias for this global array.

proc HttpdAccept {sock ipaddr port} {
    global Httpd
    upvar #0 Httpd$sock data

    Count accepts
    Count sockets
    set data(ipaddr) $ipaddr
    HttpdReset $sock $Httpd(maxused)
}

# Initialize or reset the socket state
# We allow multiple transactions per socket (keep alive),
# but handle them serially.

proc HttpdReset {sock {left {}}} {
    global Httpd
    upvar #0 Httpd$sock data

    Count connections

    # count down transations
    if {[string length $left]} {
	set data(left) $left
    } else {
	set left [incr data(left) -1]
    }
    flush $sock
    set ipaddr $data(ipaddr)
    unset data
    array set data [list state start linemode 1 version 0 \
	    left $left ipaddr $ipaddr]
    # Close the socket if it is not reused within a timeout
    set data(cancel) [after $Httpd(timeout1) \
	[list Httpd_SockClose $sock 1 ""]]
    fconfigure $sock -blocking 0 -buffersize $Httpd(bufsize) \
	-translation {auto crlf}
    fileevent $sock readable [list HttpdRead $sock]
    fileevent $sock writable {}
}

# Really need to fix the core to support DNS lookups.
# This routine is not used anywhere.

proc Httpd_Peername {sock} {
    # This is expensive!
    fconfigure $sock -peername
}

# Read request from a client.  This is the main state machine
# for the protocol.

proc HttpdRead {sock} {
    global Httpd
    upvar #0 Httpd$sock data

    # Use line mode to read the request and the mime headers

    if {$data(linemode)} {
	if [catch {gets $sock line} readCount] {
	    Httpd_SockClose $sock 1 "read error: $readCount"
	    return
	}

	# State machine is a function of our state variable:
	#	start: the connection is new
	#	mime: we are reading the protocol headers
	# and how much was read. Note that
	# [string compare $readCount 0] maps -1 to -1, 0 to 0, and > 0 to 1
    
	set state [string compare $readCount 0],$data(state)
	switch -glob -- $state {
	    1,start	{
		if [regexp {^([^ ]+) +([^?]+)\??([^ ]*) +HTTP/(1.[01])} \
			$line x data(proto) data(url) data(query) data(version)] {
		    set data(state) mime
		    set data(line) $line
		    set data(uri) $data(url)
		    if {[string length $data(query)]} {
			append data(uri) ?$data(query)
		    }
		    CountHist urlhits
		    # Limit the time allowed to serve this request
		    catch {after cancel $data(cancel)}
		    set data(cancel) [after $Httpd(timeout2) \
			[list HttpdCancel $sock]]
		} else {
		    Httpd_Error $sock 400 $line
		}
	    }
	    0,start {
		# This can happen in between requests.
	    }
	    1,mime	{
		# This regexp picks up
		# key: value
		# MIME headers.  MIME headers may be continue with a line
		# that starts with spaces.
		if [regexp {^([^ :]+):[ 	]*(.*)} $line dummy key value] {
		    set key [string tolower $key]
		    if [info exists data(mime,$key)] {
			append data(mime,$key) ,$value
		    } else {
			set data(mime,$key) $value
		    }
		    set data(key) $key
		} elseif {[regexp {^[ 	]+(.*)}  $line dummy value]} {
		    # Are there really continuation lines in the spec?
		    if [info exists data(key)] {
			append data(mime,$data(key)) " " $value
		    } else {
			Httpd_Error $sock 400 $line
		    }
		} else {
		    Httpd_Error $sock 400 $line
		}
	    }
	    0,mime	{
	        if {$data(proto) == "POST" && \
	        	[info exists data(mime,content-length)]} {
		    set data(linemode) 0
	            set data(count) $data(mime,content-length)
	            if {$data(version) >= 1.1 && [info exists data(mime,expect)]} {
	                if {$data(mime,expect) == "100-continue"} {
			    puts $sock "100 Continue HTTP/1.1\n"
			    flush $sock
			} else {
			    Httpd_Error $sock 419 $data(mime,expect)
			}
		    }
		    fconfigure $sock  -translation {binary crlf}
		} elseif {$data(proto) != "POST"}  {
		    # Dispatch upon blank line after headers
		    fileevent $sock readable {}
		    Url_Dispatch $sock
	        } else {
		    Httpd_Error $sock 411 "Confusing mime headers"
	        }
	    }
	    -1,* {
		if {[fblocked $sock]} {
		    # Blocked before getting a whole line
		    return
		}
		if {[eof $sock]} {
		    Httpd_SockClose $sock 1 ""
		    return
		}
	    }
	    default {
		Httpd_Error $sock 404 "$state ?? [expr {[eof $sock] ? "EOF" : ""}]"
	    }
	}
    } elseif {![eof $sock]} {

	# TclHttpd used to read all the post data here and
	# blindly merge it with the query data from the URL.
	# For compatibility, this is postponed until either
	# Url_DecodeQuery is called or Httpd_GetPostData is called.

	fileevent $sock readable {}
	Url_PostHook $sock $data(count)
	Url_Dispatch $sock
    } else {
	Httpd_Log $sock Error "Broken connection reading POST data"
	Httpd_SockClose $sock 1 "broken connection during post data"
    }
}

# Httpd_PostDataSize --
#
# Arguments:
#	sock	Client connection
#
# Results:
#	The amount of post data available.

proc Httpd_PostDataSize {sock} {
    upvar #0 Httpd$sock data

    if {![info exist data(count)]} {
	return 0
    }
    return $data(count)
}

# Httpd_GetPostData --
#
# Arguments:
#	sock	Client connection
#	varName	Name of buffer variable to append post data to
#	size	Amount of data to read this call. -1 to read all available.
#
# Results:
#	The amount of data left to read.  When this goes to zero, you are done.

proc Httpd_GetPostData {sock varName {size -1}} {
    upvar #0 Httpd$sock data
    upvar 1 $varName buffer

    if {![info exist data(count)] || $data(count) == 0} {
	return 0
    }
    if {$size < 0 || $size > $data(count)} {
	set size $data(count)
    }
    set block [read $sock $size]
    append buffer $block
    set data(count) [expr {$data(count) - [string length $block]}]
    return $data(count)
}

# Httpd_GetPostChannel --
#
# Arguments:
#	sock		Client connection
#	sizeName	Name of variable to get the amount of post
#			data expected to be read from the channel
#
# Results:
#	The socket, as long as there is POST data to read

proc Httpd_GetPostChannel {sock sizeName} {
    upvar #0 Httpd$sock data
    upvar 1 $sizeName size

    if {![info exist data(count)]} {
	error "no post data"
    }
    set size $data(count)
    return $sock
}

# HttpdPostData --
# This accepts the post data.  There may be a conflict between
# query data in the url and post data - you choose:
# combine: use both sources of information
# getwins: only the URL query data is used (like Apache)
# postwins: only the POST query data is used

set Httpd(postget) combine

proc HttpdPostData {sock postdata} {
    global Httpd
    upvar #0 Httpd$sock data

    if {! [info exists data(postlength)]} {
	# First read of post data
	set data(postlength) [string length $postdata]
	if {[info exists data(query)] && [string length $data(query)]} {
	    switch $Httpd(postget) {
		combine {
		    append data(query) &$postdata
		}
		getwins {
		    # This is what apache does - ignore the post data.
		    unset data(postlength)
		}
		postwins {
		    # Ignore the URL query data
		    set data(query) $postdata
		}
	    }
	} else {
	    set data(query) $postdata
	}
    } else {
	append data(query) $postdata
	incr data(postlength) [string length $postdata]
    }
    set data(count) [expr {$data(mime,content-length) - $data(postlength)}]
    if {$data(count) == 0} {
	return 1
    } else {
	return 0
    }
}

# The following are several routines that return replies

# See if we should close the socket
#  sock:  the connection handle

proc HttpdClose {sock} {
    upvar #0 Httpd$sock data

    if {[info exists data(mime,connection)]} {
	if {[string tolower $data(mime,connection)] == "keep-alive"} {
	    Count keepalive
	    set close 0
	} else {
	    Count connclose
	    set close 1
	}
    } elseif {$data(version) >= 1.1} {
	Count http1.1
    	set close 0
    } else {
	# HTTP/1.0
	Count http1.0
	set close 1
    }
    if {[expr {$data(left) == 0}]} {
	# Exceeded transactions per connection
	Count noneleft
    	set close 1
    }
    return $close
}

# HttpdRespondHeader
#
#	Utility routine for outputting response headers for normal data Does
#	not output the end of header markers so additional header lines can be
#	added
#
# Arguments:
#	sock	The connection handle
#	type	The mime type of this response
#	close	If true, signal connection close headers.  See HttpdClose
#	size	The size "in bytes" of the response
#	code	The return code - defualts to 200
#
# Side Effects:
# 	Outputs header lines

proc HttpdRespondHeader {sock type close size {code 200}} {
    global Httpd Httpd_Errors
    upvar #0 Httpd$sock data

    set data(code) $code
    append reply "HTTP/$data(version) $code $Httpd_Errors($code)" \n
    append reply "Date: [HttpdDate [clock seconds]]" \n
    append reply "Server: $Httpd(server)\n"

    if {$close} {
	append reply "Connection: Close" \n
    } elseif {$data(version) == 1.0 && !$close} {
	append reply "Connection: Keep-Alive" \n
    }
    append reply "Content-Type: $type" \n
    if {[string length $size]} {
	append reply "Content-Length: $size" \n
    }
    puts -nonewline $sock $reply
}

# Httpd_SetCookie
#	Define a cookie to be used in a reply
#	Call this before using Httpd_ReturnFile or
#	Httpd_ReturnData
#
# Arguments:
#	sock	handle on the connection
#	cookie	Set-Cookie line

proc Httpd_SetCookie {sock cookie} {
    upvar #0 Httpd$sock data
    lappend data(set-cookie) $cookie
}

# HttpdSetCookie
#	Generate the Set-Cookie headers in a reply
#	Use Httpd_SetCookie to register cookes eariler
#
# Arguments:
#	sock	handle on the connection

proc HttpdSetCookie {sock} {
    upvar #0 Httpd$sock data
    if {[info exist data(set-cookie)]} {
	foreach item $data(set-cookie) {
	    puts $sock "Set-Cookie: $item"
	}
	# HttpdCookieLog $sock HttpdSetCookie
	unset data(set-cookie)
    }
}

# Httpd_ReturnFile
#	Return a file.
#
# Arguments:
#	sock	handle on the connection
#	type	is a Content-Type
#	path	is the file pathname
#
# Side Effects:
#	Sends the file contents back as the reply.

proc Httpd_ReturnFile {sock type path} {
    global Httpd
    upvar #0 Httpd$sock data

    Count urlreply
    set data(file_size) [file size $path]
    set close [HttpdClose $sock]
    HttpdRespondHeader $sock $type $close $data(file_size) 200
    HttpdSetCookie $sock
    puts $sock "Last-Modified: [HttpdDate [file mtime $path]]"
    puts $sock ""
    if {$data(proto) != "HEAD"} {
	set in [open $path]		;# checking should already be done
	fconfigure $in -translation binary -blocking 1
	fconfigure $sock -translation binary -blocking $Httpd(sockblock)
	set data(infile) $in
	if {$Httpd(fcopy)} {
	    fcopy $in $sock -command [list HttpdCopyDone $in $sock $close]
	} else {
	    if [HttpdCopy $in $sock $close] {
		# More to copy
		fileevent $sock writable [list HttpdCopy $in $sock $close]
	    }
	}
    } else {
	Httpd_SockClose $sock $close
    }
}

# Httpd_ReturnData -- return data
# type - a Content-Type
# content - the data to return
# code - the HTTP reply code.

proc Httpd_ReturnData {sock type content {code 200}} {
    global Httpd Httpd_Errors
    upvar #0 Httpd$sock data

    Count urlreply
    set close [HttpdClose $sock]
    HttpdRespondHeader $sock $type $close [string length $content] $code
    HttpdSetCookie $sock
    puts $sock ""
    if {$data(proto) != "HEAD"} {
	fconfigure $sock -translation binary -blocking $Httpd(sockblock)
	puts -nonewline $sock $content
    }
    Httpd_SockClose $sock $close
}

# Httpd_ReturnData -- return data with a Last-Modified time so
# that proxy servers can cache it.  Or they seem to, anyway.
# type - a Content-Type
# content - the data to return
# code - the HTTP reply code.

proc Httpd_ReturnCacheableData {sock type content date {code 200}} {
    global Httpd Httpd_Errors
    upvar #0 Httpd$sock data

    Count urlreply
    set close [HttpdClose $sock]
    HttpdRespondHeader $sock $type $close [string length $content] $code
    HttpdSetCookie $sock
    puts $sock "Last-Modified: [HttpdDate $date]"
    puts $sock ""
    if {$data(proto) != "HEAD"} {
	fconfigure $sock -translation binary -blocking $Httpd(sockblock)
	puts -nonewline $sock $content
    }
    Httpd_SockClose $sock $close
}

# HttpdCopy -- 
# utility used in bulk transfer with unsupported0 (a.k.a. copychannel)
# If this returns 1, the caller should schedule another read event
# to copy the remaining data.

proc HttpdCopy {in sock close} {
    global Httpd
    if [catch {
	    if {[info exists Httpd(copytest)] && $Httpd(copytest)} {
		# 8.0 handles binary read/puts
		puts -nonewline $sock [read $in $Httpd(bufsize)]
	    } else {
		copychannel $in $sock $Httpd(bufsize)
	    }
    } oops] {
	Log $sock CopyError $oops
	Httpd_SockClose $sock 1 "copychannel error"
	return 0
    }
    if [eof $in] {
	Httpd_SockClose $sock $close
	return 0
    }
    return 1
}

# HttpdCopyDone -- this is used with fcopy when the copy completes.
# Note that tcl8.0b1 had a bug in that errors during fcopy called
# bgerror instead of this routine, which causes leaks.  Don't use b1.

proc HttpdCopyDone {in sock close bytes {error {}}} {
    catch {close $in}
    Httpd_SockClose $sock $close
}

# Cancel a transaction if the client doesn't complete the request fast enough.

proc HttpdCancel {sock} {
    upvar #0 Httpd$sock data
    Count cancel
    Httpd_Error $sock 408
}

# generic error response

set Httpd_ErrorFormat {
    <title>Httpd_Error: %1$s</title>
    Got the error <b>%2$s</b><br>
    while trying to obtain <b>%3$s</b>.
}

# send the error message, log it, and close the socket.
# Note that the Doc module tries to present a more palatable
# error display page, but falls back to this if necessary.

proc Httpd_Error {sock code {detail ""}} {
    upvar #0 Httpd$sock data
    global Httpd Httpd_Errors Httpd_ErrorFormat

    Count errors
    append data(url) ""
    if {[info exists data(code)]} {
	set detail "OLDCODE $code $detail"
    }
    if [info exists data(infile)] {
	set detail "BUSY $detail"
    }
    set data(code) $code
    set message [format $Httpd_ErrorFormat $code $Httpd_Errors($code)  $data(url)]
    append message <br>$detail
    if {$code == 500} {
	append message "<h2>Tcl Call Trace</h2>"
	for {set l [expr [info level]-1]} {$l > 0} {incr l -1} {
		append message "$l: [info level $l]<br>"
	}
    }
    Log $sock Error $code $data(url) $detail
    if [info exists data(infile)] {
	# We've already started a reply, so just bail out
	Httpd_SockClose $sock 1
	return
    }
    if [catch {
	HttpdRespondHeader $sock text/html 1 [string length $message] $code
	puts $sock ""
	puts $sock $message
    } err] {
	Log $sock LostSocket $data(url) $err
    }
    Httpd_SockClose $sock 1
}

set HttpdRedirectFormat {
    <html><head>
    <title>Found</title>
    </head><body>
    This document has moved to a new <a href="%s">location</a>.
    Please update your documents and hotlists accordingly.
    </body></html>
}

# Generate a redirect reply (code 302)

proc Httpd_Redirect {newurl sock} {
    upvar #0 Httpd$sock data
    global Httpd Httpd_Errors HttpdRedirectFormat

    set message [format $HttpdRedirectFormat $newurl]
    set close [HttpdClose $sock]
    HttpdRespondHeader $sock text/html $close [string length $message] 302
    HttpdSetCookie $sock
    puts $sock "Location: $newurl"
    puts $sock ""
    # The -nonewline is important here to work properly with
    # keep-alive connections
    puts -nonewline $sock $message
    Httpd_SockClose $sock $close
}

# Generate a redirect to another URL on this server.

proc Httpd_RedirectSelf {newurl sock} {
    global Httpd
    Httpd_Redirect [Httpd_SelfUrl $newurl] $sock
    return $newurl
}

# Create an absolute URL for this server

proc Httpd_SelfUrl {url} {
    global Httpd
    set newurl http://$Httpd(name)
    if {$Httpd(port) != 80} {
	append newurl :$Httpd(port)
    }
    append newurl $url
}

# Generate a redirect because the trailing slash isn't present
# on a URL that corresponds to a directory.

proc Httpd_RedirectDir {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    set url http://$Httpd(name)
    if {$Httpd(port) != 80} {
	append url :$Httpd(port)
    }
    Httpd_Redirect $url$data(url)/ $sock
}

set HttpdAuthorizationFormat {
    <HTML><HEAD>
    <TITLE>401 Authorization Required</TITLE>
    </HEAD><BODY>
    <H1>Authorization Required</H1>
    This server could not verify that you
    are authorized to access the document you
    requested.  Either you supplied the wrong
    credentials (e.g., bad password), or your
    browser doesn't understand how to supply
    the credentials required.<P>
    </BODY></HTML>
}

# Generate the (401) Authorization required reply
# type - usually "Basic"
# realm - browsers use this to cache credentials

proc Httpd_RequestAuth {sock type realm} {
    upvar #0 Httpd$sock data
    global Httpd Httpd_Errors HttpdAuthorizationFormat

    set close [HttpdClose $sock]
    HttpdRespondHeader $sock text/html $close [string length $HttpdAuthorizationFormat] 401
    puts $sock "Www-Authenticate: $type realm=\"$realm\""
    puts $sock ""
    puts -nonewline $sock $HttpdAuthorizationFormat
    Httpd_SockClose $sock $close
}

# generate a date string in HTTP format

proc HttpdDate {seconds} {
    return [clock format $seconds -format {%a, %d %b %Y %T GMT} -gmt true]
}


# Close a socket.  We'll use this for keep-alives some day.

proc Httpd_SockClose {sock closeit {message Close}} {
    upvar #0 Httpd$sock data

    if {[string length $message]} {
	Log $sock $message
    }
    Count connections -1
    if [info exists data(cancel)] {
	after cancel $data(cancel)
    }
    catch {close $data(infile)}
    if {$closeit} {
	Count sockets -1
	if [catch {close $sock} err] {
	    Log $sock CloseError $err
	}
	unset data
    } else {
	HttpdReset $sock
    }
}


# server specific version of bgerror - indent to hide from indexer

    proc bgerror {msg} {
	global errorInfo

	set msg "[clock format [clock seconds]]\n$errorInfo"
	if [catch {Log nosock bgerror $msg}] {
	    catch {puts stderr $msg}
	}
    }

proc HttpdCookieLog {sock what} {
    global Log Httpd
    upvar #0 Httpd$sock data
    if {[info exist Log(log)] && ![info exist Httpd(cookie_log)]} {
	set Httpd(cookie_log) [open $Log(log)cookie a]
    }
    if {[info exist Httpd(cookie_log)]} {
	append result [LogValue data(ipaddr)]
	append result { } \[[clock format [clock seconds] -format %d/%h/%Y:%T] -0700\]

	append result { } $what
	switch $what {
	    Url_Dispatch {
		if {![info exist data(mime,cookie)]} {
		    return
		}
		append result { } \"$data(mime,cookie)\"
	    }
	    Httpd_SetCookie -
	    HttpdSetCookie {
		append result { } \"[LogValue data(set-cookie)]\"
	    }
	}
	catch { puts $Httpd(cookie_log) $result ; flush $Httpd(cookie_log)}
    }
}
