# httpd.tcl --
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
# For async operation, such as long-lasting server-side operations use
# Httpd_Suspend.
#
# Copyright
# Matt Newman (c) 1999 Novadigm Inc.
# Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: httpd.tcl,v 1.53 2000/09/13 21:50:49 welch Exp $

package provide httpd 1.4

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
# by Cgi_SetEnv.  The values are keys into the
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
    HTTP_FORWARDED      mime,forwarded
    HTTP_HOST           mime,host
    HTTP_PROXY_CONNECTION mime,proxy-connection
    REMOTE_USER		remote_user
    AUTH_TYPE		auth_type
}

# Httpd_Init
#	Initialize the httpd module.  Call this early, before Httpd_Server.
#
# Arguments:
#	none
#
# Side Effects:
#	Initialize the global Httpd array.
# bufsize:	Chunk size for copies
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
# timeout3:	Time allowed to drain extra post data
# version:	The version number.
# maxused:	Max number of transactions per socket (keep alive)

proc Httpd_Init {} {
    global Httpd
    array set Httpd {
	timeout1	120000
	timeout2	120000
	timeout3	2000
	server		"Tcl-Webserver/"
	initialized 	1
	shutdown	""
	sockblock	0
	bufsize		16384
	maxused		25
    }
    if {![info exist Httpd(maxthreads)]} {
	set Httpd(maxthreads) 0
    }
    Httpd_Version
    append Httpd(server) $Httpd(version)

    # TODO - move these OUT of this file and into the main startup code

    Counter_Init

}

# Httpd_Server --
#	Start the server by listening for connections on the desired port.
#	This may be re-run to re-start the server.  Call this late,
# 	fter Httpd_Init and the init calls for the other modules.
#
# Arguments:
#	port	The TCP listening port number
#	name	The qualified host name returned in the Host field.  Defaults
#		to [info hostname]
#	ipaddr	Non-default interface address.  Otherwise IP_ADDR_ANY is used
#		so the server can accept connections from any interface.
#
# Results:
#	none
#
# Side Effects:
#	This sets up a callback to HttpdAccept for new connections.

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
    set cmd [list socket -server [list HttpdAccept \
	    [list http $name $port]]]
    if {[string length $ipaddr] != 0} {
        lappend cmd -myaddr $ipaddr
    }
    lappend cmd $port
    if {[catch $cmd Httpd(listen)]} {
        return -code error "$Httpd(name):$port $Httpd(listen)\ncmd=$cmd"
    }
    Counter_Reset accepts
}

# Httpd_SecureServer --
#
#	Like Httpd_Server, but with additional setup for SSL.
#	This requires the TLS extension.
#
# Arguments:
#	port	The TCP listening port number
#	name	The qualified host name returned in the Host field.  Defaults
#		to [info hostname]
#	ipaddr	Non-default interface address.  Otherwise IP_ADDR_ANY is used
#		so the server can accept connections from any interface.
#
# Results:
#	none
#
# Side Effects:
#	This sets up a callback to HttpdAccept for new connections.

proc Httpd_SecureServer {{port 443} {name {}} {ipaddr {}}} {
    global Httpd

    if {![info exists Httpd(initialized)]} {
	Httpd_Init
    }
    catch {close $Httpd(https_listen)}
    set Httpd(name) $name
    set Httpd(https_ipaddr) $ipaddr
    set Httpd(https_port) $port
    if {[string length $name] == 0} {
	set Httpd(name) [info hostname]
    }
    package require tls

    # This now depends on a call to tls::init being made elsewhere, typically
    # in the main startup script.  That call sets all the various SSL parameters
    # based on the server's configuration file.

    set cmd [list tls::socket -server [list HttpdAccept \
	    [list https $name $port]]]
    if {[string length $ipaddr] != 0} {
        lappend cmd -myaddr $ipaddr
    }
    lappend cmd $port
    if {[catch $cmd Httpd(https_listen)]} {
        return -code error "$Httpd(name):$port $Httpd(https_listen)\ncmd=$cmd"
    }
    Counter_Reset accepts
}

# Httpd_Shutdown --
#
#	Kill the server gracefully
#
# Arguments:
#	none
#
# Results:
#	none
#
# Side Effects:
#	Close the server listening socket(s)
#	Invoke any registered shutdown procedures.

proc Httpd_Shutdown {} {
    global Httpd
    set ok 1
    foreach handler $Httpd(shutdown) {
	if {[catch {eval $handler} err]} {
	    Log "" "Shutdown: $handler" $err
	    set ok 0
	}
    }
    Log {} Shutdown
    catch {close $Httpd(listen)}
    catch {close $Httpd(https_listen)}
    return $ok
}

# Httpd_RegisterShutdown --
#
#	Register a Tcl command to be called by Httpd_Shutdown
#
# Arguments:
#	cmd	The command to eval from Httpd_Shutdown
#
# Results:
#	none
#
# Side Effects:
#	Save the callback.

proc Httpd_RegisterShutdown {cmd} {
    global Httpd
    if {[lsearch $Httpd(shutdown) $cmd] < 0} {
	lappend Httpd(shutdown) $cmd
    }
}

# HttpdAccept --
#
#	This is the socket accept callback invoked by Tcl when
#	clients connect to the server.
#
# Arguments:
#	self	A list of {protocol name port} that identifies the server
#	sock	The new socket connection
#	ipaddr	The client's IP address
#	port	The client's port
#
# Results:
#	none
#
# Side Effects:
#	Set up a handler, HttpdRead, to read the request from the client.
#	The per-connection state is kept in Httpd$sock, (e.g., Httpdsock6),
#	and upvar is used to create a local "data" alias for this global array.

proc HttpdAccept {self sock ipaddr port} {
    global Httpd
    upvar #0 Httpd$sock data

    Count accepts
    Count sockets
    set data(self) $self
    set data(ipaddr) $ipaddr
    if {[Httpd_Protocol $sock] == "https"} {
	
	# There is still a lengthy handshake that must occur.
	# We do that by calling tls::handshake in a fileevent
	# until it is complete, or an error occurs.

	set data(ssl) 1
	fconfigure $sock -blocking 0
	fileevent $sock readable [list HttpdHandshake $sock]
    } else {
	HttpdReset $sock $Httpd(maxused)
    }
}

# HttpdHandshake --
#
#	Complete the SSL handshake. This is called from a fileevent
#	on a new https connection.  It calls tls::handshake until done.
#
# Arguments:
#	sock	The socket connection
#
# Results:
#	none
#
# Side Effects:
#	If the handshake fails, close the connection.
#	Otherwise, call HttpdReset to set up the normal HTTP protocol.

proc HttpdHandshake {sock} {
    upvar #0 Httpd$sock data
    global Httpd errorCode
	
    if {[catch {tls::handshake $sock} complete]} {
	if {[lindex $errorCode 1] == "EAGAIN"} {
	    # This seems to occur normally on UNIX systems
	    return
	}
	Log $sock "HttpdHandshake" "\{$data(self)\} $sock \
	    $data(ipaddr) $complete"
	Httpd_SockClose $sock 1 "$complete"
    } elseif {$complete} {
	set data(cert) [tls::status $sock]
	HttpdReset $sock $Httpd(maxused)
    }
}

# HttpdReset --
#
#	Initialize or reset the socket state.
#	We allow multiple transactions per socket (keep alive).
#
# Arguments:
#	sock	The socket connection
#	left	(optional) The keepalive connection count.
#
# Results:
#	none
#
# Side Effects:
#	Resets the "data" array.
#	Cancels any after events.
#	Closes the socket upon error or if the reuse counter goes to 0.
#	Sets up the fileevent for HttpdRead

proc HttpdReset {sock {left {}}} {
    global Httpd
    upvar #0 Httpd$sock data

    if {[catch {
	flush $sock
    } err]} {
	Httpd_SockClose $sock 1 $err
	return
    }
    Count connections

    # Count down transactions.

    if {[string length $left]} {
	set data(left) $left
    } else {
	set left [incr data(left) -1]
    }
    if {[info exists data(cancel)]} {
	after cancel $data(cancel)
    }

    # Clear out (most of) the data array.

    set ipaddr $data(ipaddr)
    set self $data(self)
    if {[info exist data(cert)]} {
	set cert $data(cert)
    }
    unset data
    array set data [list state start version 0 \
	    left $left ipaddr $ipaddr self $self]
    if {[info exist cert]} {
	set data(cert) $cert
    }

    # Set up a timer to close the socket if the next request
    # is not completed soon enough.  The request has already
    # been started, but a bad client might not finish.

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

    if {[catch {gets $sock line} readCount]} {
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
	    if {[regexp {^([^ ]+) +([^?]+)\??([^ ]*) +HTTP/(1.[01])} \
		    $line x data(proto) data(url) data(query) data(version)]} {
		
		# data(uri) is the complete URI

		set data(uri) $data(url)
		if {[string length $data(query)]} {
		    append data(uri) ?$data(query)
		}

		# Strip leading http://server and look for the proxy case.

		if {[regexp {^https?://([^/:]+)(:([0-9]+))?(.*)$} $data(url) \
			x xserv y xport urlstub]} {
		    set myname [Httpd_Name $sock]
		    set myport [Httpd_Port $sock]
		    if {([string compare \
			    [string tolower $xserv] \
			    [string tolower $myname]] != 0) ||
			    ($myport != $xport)} {
			set data(host) $xserv
			set data(port) $xport
		    }
		    # Strip it out if it is for us (i.e., redundant)
		    # This makes it easier for doc handlers to
		    # look at the "url"
		    set data(url) $urlstub
		}
		set data(state) mime
		set data(line) $line
		CountHist urlhits

		# Limit the time allowed to serve this request

		if {[info exists data(cancel)]} {
		    after cancel $data(cancel)
		}
		set data(cancel) [after $Httpd(timeout2) \
		    [list HttpdCancel $sock]]
	    } else {
		# Could check for FTP requests, here...
		Log $sock HttpError $line
		Httpd_SockClose $sock 1
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
	    if {[regexp {^([^ :]+):[ 	]*(.*)} $line dummy key value]} {
		set key [string tolower $key]
		if [info exists data(mime,$key)] {
		    append data(mime,$key) ,$value
		} else {
		    set data(mime,$key) $value
		    lappend data(mimeorder) $key
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
	    if {$data(proto) == "POST"} {
		fconfigure $sock  -translation {binary crlf}
		if {![info exists data(mime,content-length)]} {
		    Httpd_Error $sock 411 $data(mime,expect)
		    return
		}
		set data(count) $data(mime,content-length)
		if {$data(version) >= 1.1 && [info exists data(mime,expect)]} {
		    if {$data(mime,expect) == "100-continue"} {
			puts $sock "100 Continue HTTP/1.1\n"
			flush $sock
		    } else {
			Httpd_Error $sock 419 $data(mime,expect)
			return
		    }
		}

		# Flag the need to check for an extra newline
		# in SSL connections by some browsers.

		set data(checkNewline) 1

		# Facilitate a backdoor hook between Url_DecodeQuery
		# where it will read the post data on behalf of the
		# domain handler in the case where the domain handler
		# doesn't use an Httpd call to read the post data itself.

		Url_PostHook $sock $data(count)
	    } else {
		set data(count) 0
	    }

	    # Disabling this fileevent makes it possible to use
	    # http::geturl in domain handlers reliably

	    fileevent $sock readable {}

	    # The use of HTTP_CHANNEL is a disgusting hack.

	    set ::env(HTTP_CHANNEL) $sock

	    # Do a different dispatch for proxies.  By default, no proxy.

	    if {[info exist data(host)]} {
		if {[catch {
		    Proxy_Dispatch $sock
		} err]} {
		    Httpd_Error $sock 400 "No proxy support\n$err"
		}
	    } else {
		Url_Dispatch $sock
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
    global Httpd
    upvar #0 Httpd$sock data
    upvar 1 $varName buffer

    if {$size < 0} {
	set size $Httpd(bufsize)
    }
    HttpdReadPost $sock buffer $size
    return $data(count)
}

# Httpd_GetPostDataAsync --
#
#	Read the POST data into a Tcl variable, but do it in the
#	background so the server doesn't block on the socket.
#
# Arguments:
#	sock	Client connection
#	varName	Name of buffer variable to append post data to.  This
#		must be a global or fully scoped namespace variable, or
#		this can be the empty string, in which case the data
#		is discarded.
#	blockSize	Default read block size.
#	cmd	Callback to make when the post data has been read.
#		It is called like this:
#		cmd $sock $varName $errorString
#		Where the errorString is only passed if an error occurred.
#
# Side Effects:
#	This schedules a readable fileevent to read all the POST data
#	asynchronously.  The data is appened to the named variable.
#	The callback is made 

proc Httpd_GetPostDataAsync {sock varName blockSize cmd} {
    fileevent $sock readable \
	[list HttpdReadPostGlobal $sock $varName $blockSize $cmd]
    return
}

proc HttpdReadPostGlobal {sock varName blockSize {cmd {}}} {

    # This fileevent callback can only access a global variable.
    # But HttpdReadPost needs to affect a local variable in its
    # caller so it can be shared with Httpd_GetPostData.
    # So, the fileevent case has an extra procedure frame.

    upvar #0 $varName buffer
    HttpdReadPost $sock buffer $blockSize $cmd
}

proc HttpdReadPost {sock varName blockSize {cmd {}}} {
    global Httpd
    upvar #0 Httpd$sock data

    # Ensure that the variable, if specified, exists by appending "" to it

    if {[string length $varName]} {
	upvar 1 $varName buffer
	append buffer ""
    }

    if {[eof $sock]} {
	if {$data(count)} {
	    set doneMsg "Short read: got [string length $buffer] bytes,\
		expected $data(count) more bytes"
	    set data(count) 0
	} else {
	    set doneMsg ""
	}
    } else {
	if {[info exist data(checkNewline)]} {

	    # Gobble a single leading \n from the POST data
	    # This is generated by various versions of Netscape
	    # when using https/SSL.  This extra \n is not counted
	    # in the content-length (thanks!)

	    set nl [read $sock 1]
	    if {[string compare $nl \n] != 0} {

		# It was not an extra newline.

		incr data(count) -1
		if {[info exist buffer]} {
		    append buffer $nl
		}
	    }
	    unset data(checkNewline)
	}
	set toRead [expr {$data(count) > $blockSize ? \
		$blockSize : $data(count)}]
	if {[catch {read $sock $toRead} block]} {
	    set doneMsg $block
	    set data(count) 0
	} else {
	    if {[info exist buffer]} {
		append buffer $block
	    }
	    set data(count) [expr {$data(count) - [string length $block]}]
	    if {$data(count) == 0} {
		set doneMsg ""
	    }
	}
    }
    if {[info exist doneMsg]} {
	Url_PostHook $sock 0
	if {[string length $cmd]} {
	    eval $cmd [list $sock $varName $doneMsg]
	}
	catch {fileevent $sock readable {}}
	return $doneMsg
    } else {
	return ""
    }
}

# Httpd_CopyPostData --
#
#	Copy the POST data to a channel and make a callback when that
#	has completed.
#
# Arguments:
#	sock	Client connection
#	channel	Channel, e.g., to a local file or to a proxy socket.
#	cmd	Callback to make when the post data has been read.
#		It is called like this:
#		    cmd $sock $channel $bytes $errorString
#		Bytes is the number of bytes transferred by fcopy.
#		errorString is only passed if an error occurred,
#		otherwise it is an empty string
#
# Side Effects:
#	This uses fcopy to transfer the data from the socket to the channel.

proc Httpd_CopyPostData {sock channel cmd} {
    upvar #0 Httpd$sock data
    fcopy $sock $channel -size $data(count) \
    	-command [concat $cmd $sock $channel]
    Url_PostHook $sock 0
    return
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

    if {$data(count) == 0} {
	error "no post data"
    }
    set size $data(count)
    return $sock
}

# The following are several routines that return replies

# HttpdCloseP --
#	See if we should close the socket
#
# Arguments:
#	sock	the connection handle
#
# Results:
#	1 if the connection should be closed now, 0 if keep-alive

proc HttpdCloseP {sock} {
    upvar #0 Httpd$sock data

    if {[info exists data(mime,connection)]} {
	if {[string tolower $data(mime,connection)] == "keep-alive"} {
	    Count keepalive
	    set close 0
	} else {
	    Count connclose
	    set close 1
	}
    } elseif {[info exists data(mime,proxy-connection)]} {
	if {[string tolower $data(mime,proxy-connection)] == "keep-alive"} {
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

# HttpdRespondHeader --
#
#	Utility routine for outputting response headers for normal data Does
#	not output the end of header markers so additional header lines can be
#	added
#
# Arguments:
#	sock	The connection handle
#	type	The mime type of this response
#	close	If true, signal connection close headers.  See HttpdCloseP
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

proc Httpd_ReturnFile {sock type path {offset 0}} {
    global Httpd
    upvar #0 Httpd$sock data

    if {[Thread_Respond $sock \
	    [list Httpd_ReturnFile $sock $type $path $offset]]} {
	return
    }

    Count urlreply
    set data(file_size) [file size $path]

    # Some files have a duality, when the client sees X bytes but the
    # file is really X + n bytes (the first n bytes reserved for server
    # side accounting information.

    incr data(file_size) -$offset

    set close [HttpdCloseP $sock]
    HttpdRespondHeader $sock $type $close $data(file_size) 200
    HttpdSetCookie $sock
    puts $sock "Last-Modified: [HttpdDate [file mtime $path]]"
    puts $sock ""
    if {$data(proto) != "HEAD"} {
	set in [open $path]		;# checking should already be done
	fconfigure $in -translation binary -blocking 1
	if {$offset != 0} {
	    seek $in $offset
	}
	fconfigure $sock -translation binary -blocking $Httpd(sockblock)
	set data(infile) $in
	Httpd_Suspend $sock 0
	fcopy $in $sock -command [list HttpdCopyDone $in $sock $close]
    } else {
	Httpd_SockClose $sock $close
    }
}

# Httpd_ReturnData
#	Return data for a page.
#
# Arguments:
#	type	a Content-Type
#	content	the data to return
#	code	the HTTP reply code.
#
# Side Effects:
#	Send the data down the socket

proc Httpd_ReturnData {sock type content {code 200} {close 0}} {
    global Httpd Httpd_Errors
    upvar #0 Httpd$sock data

    if {[Thread_Respond $sock \
	    [list Httpd_ReturnData $sock $type $content $code $close]]} {
	return
    }

    Count urlreply
    if {$close == 0} {
    	set close [HttpdCloseP $sock]
    }
    HttpdRespondHeader $sock $type $close [string length $content] $code
    HttpdSetCookie $sock
    puts $sock ""
    if {$data(proto) != "HEAD"} {
	fconfigure $sock -translation binary -blocking $Httpd(sockblock)
	puts -nonewline $sock $content
    }
    Httpd_SockClose $sock $close
}

# Httpd_ReturnCacheableData
#	Return data with a Last-Modified time so
#	that proxy servers can cache it.  Or they seem to, anyway.
#
# Arguments:
#	sock	Client connection
#	type	a Content-Type
#	content	the data to return
#	date	Modify date of the date
#	code	the HTTP reply code.
#
# Side Effects:
#	Send the data down the socket

proc Httpd_ReturnCacheableData {sock type content date {code 200}} {
    global Httpd Httpd_Errors
    upvar #0 Httpd$sock data

    if {[Thread_Respond $sock \
	    [list Httpd_ReturnCacheableData $sock $type $content $date $code]]} {
	return
    }

    Count urlreply
    set close [HttpdCloseP $sock]
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

# HttpdCopyDone -- this is used with fcopy when the copy completes.
# Note that tcl8.0b1 had a bug in that errors during fcopy called
# bgerror instead of this routine, which causes leaks.  Don't use b1.

proc HttpdCopyDone {in sock close bytes {error {}}} {
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

    if {[Thread_Respond $sock [list Httpd_Error $sock $code $detail]]} {
	# We've passed the error back to the main thread
	return
    }

    upvar #0 Httpd$sock data
    global Httpd Httpd_Errors Httpd_ErrorFormat

    Count errors
    append data(url) ""
    if {[info exists data(code)]} {
	set detail "OLDCODE $code $detail"
    }
    if {[info exists data(infile)]} {
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
    if {[info exists data(infile)]} {
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

    if {[Thread_Respond $sock \
	    [list Httpd_Redirect $newurl $sock]]} {
	return
    }

    set message [format $HttpdRedirectFormat $newurl]
    set close [HttpdCloseP $sock]
    HttpdRespondHeader $sock text/html $close [string length $message] 302
    HttpdSetCookie $sock
    puts $sock "Location: $newurl"
    puts $sock "URI: $newurl"
    puts $sock ""

    # The -nonewline is important here to work properly with
    # keep-alive connections

    puts -nonewline $sock $message
    Httpd_SockClose $sock $close
}

# Generate a redirect to another URL on this server.

proc Httpd_RedirectSelf {newurl sock} {
    Httpd_Redirect [Httpd_SelfUrl $newurl $sock] $sock
}

# Create an absolute URL for this server

proc Httpd_SelfUrl {url {sock ""}} {
    global Httpd env
    if {$sock == ""} {
	set sock $env(HTTP_CHANNEL)
    }
    upvar #0 Httpd$sock data

    set type [Httpd_Protocol $sock]
    set port [Httpd_Port $sock]
    if {[info exists data(mime,host)]} {

	# Use in preference to our "true" name because
	# the client might not have a DNS entry for use.

	set name $data(mime,host)
    } else {
	set name [Httpd_Name $sock]
    }
    set newurl $type://$name
    if {[string first : $name] == -1} {
	# Add in the port number, which may or may not be present in
	# the name already.  IE5 sticks the port into the Host: header,
	# while Tcl's own http package does not...

	if {$type == "http" && $port != 80} {
	    append newurl :$port
	}
	if {$type == "https" && $port != 443} {
	    append newurl :$port
	}
    }
    append newurl $url
}

# Return the protocol for the connection

proc Httpd_Protocol {sock} {
    upvar #0 Httpd$sock data
    return [lindex $data(self) 0]
}

# Return the server name for the connection

proc Httpd_Name {sock} {
    upvar #0 Httpd$sock data
    return [lindex $data(self) 1]
}

# Return the port for the connection

proc Httpd_Port {{sock {}}} {
    if {[string length $sock]} {

	# Return the port for this connection

	upvar #0 Httpd$sock data
	return [lindex $data(self) 2]
    } else {

	# Return the non-secure listening port

	global Httpd
	if {[info exist Httpd(port)]} {
	    return $Httpd(port)
	} else {
	    return {}
	}
    }
}
proc Httpd_SecurePort {} {

    # Return the secure listening port

    global Httpd
    if {[info exist Httpd(https_port)]} {
	return $Httpd(https_port)
    } else {
	return {}
    }
}


# Generate a redirect because the trailing slash isn't present
# on a URL that corresponds to a directory.

proc Httpd_RedirectDir {sock} {
    global Httpd
    upvar #0 Httpd$sock data
    Httpd_Redirect $data(url)/ $sock
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

    if {[Thread_Respond $sock \
	    [list Httpd_RequestAuth $sock $type $realm]]} {
	return
    }

    set close [HttpdCloseP $sock]
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

# Httpd_SockClose --
#	"Close" a connection, although the socket might actually
#	remain open for a keep-alive connection.
#	This means the HTTP transaction is fully complete.
#
# Arguments:
#	sock	Identifies the client connection
#	closeit	1 if the socket should close no matter what
#	message	Logging message.  If this is "Close", which is the default,
#		then an entry is made to the standard log.  Otherwise
#		an entry is made to the debug log.
#
# Side Effects:
#	Cleans up all state associated with the connection, including
#	after events for timeouts, the data array, and fileevents.

proc Httpd_SockClose {sock closeit {message Close}} {
    global Httpd
    upvar #0 Httpd$sock data

    if {[string length $message]} {
	Log $sock $message
    }
    Count connections -1
    if {[info exist data(infile)]} {

	# Close file or CGI pipe.  Still need catch because of CGI pipe.

	catch {close $data(infile)}
    }
    if {$closeit} {
	if {[info exists data(count)] && $data(count) > 0} {

	    # There is unread POST data.  To ensure that the client
	    # can read our reply properly, we must read this data.
	    # The empty variable name causes us to discard the POST data.

	    if {[info exists data(cancel)]} {
		after cancel $data(cancel)
	    }
	    set data(cancel) [after $Httpd(timeout3) \
		[list HttpdCloseFinal $sock]]

	    Httpd_GetPostDataAsync $sock "" $data(count) HttpdCloseFinal
	} else {
	    HttpdCloseFinal $sock
	}
    } else {
	HttpdReset $sock
    }
}

proc HttpdCloseFinal {sock args} {
    upvar #0 Httpd$sock data
    Count sockets -1
    if {[info exists data(cancel)]} {
	after cancel $data(cancel)
    }
    if {[catch {close $sock} err]} {
	Log $sock CloseError $err
    }
    unset data
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
	    Httpd_Dispatch {
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

# Suspend Wire Callback - for async transactions
# Use HttpdReset once you are back in business
proc Httpd_Suspend {sock {timeout ""}} {
    global Httpd
    upvar #0 Httpd$sock data

    fileevent $sock readable {}
    fileevent $sock writable {}

    if {[info exists data(cancel)]} {
	after cancel $data(cancel)
	unset data(cancel)
    }
    if {$timeout == ""} {
	set timeout $Httpd(timeout2)
    }
    if {$timeout != 0} {
	set data(cancel) [after $timeout [list HttpdCancel $sock]]
    }
}

#
# Pair two fd's - typically for tunnelling
# Close both if either one closes (or gets an error)
#
proc Httpd_Pair {sock fd} {
    global Httpd
    upvar #0 Httpd$sock data

    syslog debug "HTTP: Pairing $sock and $fd"

    Httpd_Suspend $sock 0

    fconfigure $sock -translation binary -blocking 0
    fconfigure $fd -translation binary -blocking 0

    fileevent $sock readable [list HttpdReflect $sock $fd]
    fileevent $fd readable [list HttpdReflect $fd $sock]
}

proc HttpdReflect {in out} {
    global Httpd
    if {[catch {
	set buf [read $in $Httpd(bufsize)]
	puts -nonewline $out $buf
	flush $out
	set buflen [string length $buf]
	if {$buflen > 0} {
	    syslog debug "Tunnel: $in -> $out ($buflen bytes)" 
	}
    } oops]} {
	Log $in Tunnel "Error: $oops"
    } elseif {![eof $in]} {
	return 1
    } else {
	syslog debug "Tunnel: $in EOF"
    }
    fileevent $in readable {}
    fileevent $out readable {}
    catch {flush $in}
    catch {flush $out}
    catch {close $in}
    catch {close $out}
    return 0
}

# Httpd_DumpHeaders --
#
#	Dump out the protocol headers so they can be saved for later.
#
# Arguments:
#	sock	Client connection
#
# Results:
#	A list structure that alternates between names and values.
#	The names are header names without the trailing colon and
#	mapped to lower case (e.g., content-type).  Two pseudo-headers
#	added: One that contains the original request URL; its name is "url"
#	Another that contains the request protocol; its name is "method"
#	There are no duplications in the header keys.  If any headers
#	were repeated, their values were combined by separating them
#	with commas.

proc Httpd_DumpHeaders {sock} {
    upvar #0 Httpd$sock data

    set result [list url $data(uri) method $data(proto) version $data(version)]
    if {[info exist data(mimeorder)]} {
	foreach key $data(mimeorder) {
	    lappend result $key $data(mime,$key)
	}
    }
    return $result
}
