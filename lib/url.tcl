# url.tcl
#
# This is the URL dispatcher.  The URL hierarchy is divided into "domains"
# that are subtrees of the URL space with a particular type.  A domain is
# identified by the name of its root, which is a prefix of the URLs in
# that domain.  The dispatcher selects a domain by the longest matching
# prefix, and then calls a domain handler to process the URL.  Different
# domain handlers correspond to files (Doc), cgi-bin directories (Cgi),
# and things built right into the application (Direct).
#
# URL processing is divided into two parts.  The first time a URL is
# requested the domain dispatch is done.  The domain handler finds the
# object and then caches the result by calling Url_Handle with a callback
# into a lower-level handler.  For example, Doc_Domain finds a file and
# calls Url_Handle with a Doc_Handle callback.  The next time the URL
# dispatcher sees a URL the lookup result of Doc_Domain is in UrlCache
# and Doc_Handle is called directly without going through the whole
# process done by Doc_Domain.
#
# URL redirection is done by sticking an appropriate handler in UrlCache.
#
# One problem with this scheme is that authentication cookies are kept
# in the UrlCache array, so if you add authentication to a directory you
# need to flush the UrlCache so the Doc_Domain handler does the full job
# and detects the .htaccess file.  Once a .htaccess file is installed,
# the Doc_Handler procedure correctly notices updates to that file.
#
# A second limitation is that references across domains via relative names
# are not supported. I solved this problem in the Sprite file system but
# am punting for now here.  In practice this means you should just fan
# out the URL tree at the root, as in /cgi-bin, /status, /debug, etc.
#
# Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) url.tcl 1.7 97/08/20 11:50:13

package provide url 2.0

# This pattern cannot occur inside a URL path component
# On windows we disallow : to avoid drive-letter attacks

switch $tcl_platform(platform) {
    windows	{ set Url(fsSep) {[/\\:]} }
    macintosh	{ set Url(fsSep) : }
    unix	-
    default	{ set Url(fsSep) / }
}

# Url_Dispatch
#
#	Dispatch to a type-specific handler for a URL
#
# Arguments
#	sock	THe client socket connection
#
# Side Effects
#	Handle the request

proc Url_Dispatch {sock} {
    global Url UrlCache
    upvar #0 Httpd$sock data

    catch {after cancel $data(cancel)}

    # Dispatch to cached handler for the URL, if any

    set url $data(url)
    CountName $url hit
    if {(![info exists data(query)] || ([string length $data(query)] == 0)) &&
	    ([Httpd_PostDataSize $sock] == 0) && [info exists UrlCache($url)]} {
	
	# Look aside into a command cache based on URLs.
	# This is used to avoid processing long URLs, and to
	# deal with redirects from one URL to another.
	# If the URL is handled in a worker thread, then there
	# will not be an entry in the UrlCache of this dispatch thread.

	Count UrlCacheHit
	set code [catch { eval $UrlCache($url) {$sock} } error]
	if {$code == 0} {
	    return
	}
	# Upon error, drop the command cache and fall through to
	# common error handling

	catch {Url_UnCache $sock}
    } else {
	set code [catch {

	    # Prefix match the URL to get a domain handler
	    # Fast check on domain prefixes with regexp
	    # Check that the suffix starts with /, otherwise the prefix
	    # is not a complete component.  E.g., "/tcl" vs "/tclhttpd"
	    # where /tcl is a domain prefix but /tclhttpd is a directory
	    # in the / domain.

	    if {![regexp ^($Url(prefixset))(.*) $url x prefix suffix] ||
		    ([string length $suffix] && ![string match /* $suffix])} {
		# Fall back and assume it is under the root
		regexp ^(/)(.*) $url x prefix suffix
	    }

	    # Invoke the URL domain handler either in this main thread
	    # or in a worker thread

	    if {$Url(thread,$prefix)} {
		Count UrlToThread
		Thread_Dispatch $sock \
			[concat $Url(command,$prefix) [list $sock $suffix]]
	    } else {
		Count UrlEval
		eval $Url(command,$prefix) {$sock $suffix}
	    }
	} error]
    }

    if {$code != 0} {
	global errorInfo
	global errorCode
	Url_Unwind $sock $errorInfo $errorCode
    }
}

# Url_Unwind
#	Do common error handling after a URL request
#
# Arguments
#	sock	The client connection
#	ei	The errorInfo from the command
#	ec	The errorCode from the command
#
# Side Effects
#	Clean up the connection and ensure a reply

proc Url_Unwind {sock ei ec} {

	# URL implementations can raise an error and put redirect info
	# into the errorCode variable, which should be of the form
	# HTTPD_REDIRECT $newurl

	set key [lindex $ec 0]
	set error [lindex [split $ei \n] 0]
	if {[string match HTTPD_REDIRECT $key]} {
	    Httpd_Redirect [lindex $ec 1] $sock
	    return
	}

	switch -glob -- $ei {
	    "*can not find channel*"  {
		Httpd_SockClose $sock 1 $error
	    }
	    "*too many open files*" {
		# this is lame and probably not necessary.
		# Early bugs lead to file descriptor leaks, but
		# these are all plugged up.
		Count numfiles
		Httpd_SockClose $sock 1 $error
		File_Reset
	    } 
	    default {
		Doc_Error $sock $ei
	    }
	}
    }


# Url_PrefixInstall
#	Declare that a handler exists for a point in the URL tree
#	identified by the prefix of all URLs below that point.
#
# Arguments:
#	prefix	The leadin part of the URL, (e.., /foo/bar)
#	command	THe Domain handler command.  This is invoked with one
#		additional arument, $sock, that is the handle identifier
#		A well-known state array is available at
#		upvar #0 Httpd$sock 
#	tothread	If true, this domain handler is run in a thread

proc Url_PrefixInstall {prefix command {tothread 0}} {
    global Url

    # Add the url to the prefixset, which is a regular expression used
    # to pick off the prefix from the URL

    regsub -all {([][\\().*+?$|])} $prefix {\\\1} prefixquoted

    if {[string compare $prefix "/"] == 0} {
	# / is not in the prefixset because of some special cases.
	# See Url_Dispatch
    } elseif {![info exists Url(prefixset)]} {
	set Url(prefixset) $prefixquoted
    } else {
	set list [split $Url(prefixset) |]
	if {[lsearch $list $prefixquoted] < 0} {
	    lappend list $prefixquoted
	}
	set Url(prefixset) [join [lsort -command UrlSort $list] |]
    }

    # Install the unquoted prefix so the Url dispatch works right

    set Url(command,$prefix) $command
    set Url(thread,$prefix) $tothread
}

# Undo a prefix registration

proc Url_PrefixRemove {prefix} {
    global Url

    # Delete the prefix from the regular expression used to match URLs

    set list [split $Url(prefixset) |]
    ldelete list $prefix
    set Url(prefixset) [join [lsort -command UrlSort $list] |]
}

# Sort the prefixes so the longest one is first
proc UrlSort {a b} {
    set la [string length $a]
    set lb [string length $b]
    if {$la == $lb} {
	return [string compare $a $b]
    } elseif {$la < $lb} {
	return 1
    } else {
	return -1
    }
}

# Cache the handler for the url, then invoke it

proc Url_Handle {cmd sock} {
    upvar #0 Httpd$sock data
    global UrlCache
    set UrlCache($data(url)) $cmd
    eval $cmd {$sock}
}

proc Url_UnCache {sock {force 0}} {
    upvar #0 Httpd$sock data
    global UrlCache
    if {[info exists UrlCache($data(url))]} {
	set redirect [regexp Redirect $UrlCache($data(url))]
	if {$force || !$redirect} {
	    unset UrlCache($data(url))
	}
    }
}

# Validate a pathname.  Make sure it doesn't sneak out of its domain.

proc Url_PathCheck {urlsuffix} {
    global Url
    set pathlist ""
    foreach part  [split $urlsuffix /] {
	if {[string length $part] == 0} {

	    # It is important *not* to "continue" here and skip
	    # an empty component because it could be the last thing,
	    # /a/b/c/
	    # which indicates a directory.  In this case you want
	    # Auth_Check to recurse into the directory in the last step.

	}
	set part [Url_Decode $part]
	# Disallow Mac and UNIX path separators in components
	# Windows drive-letters are bad, too
	if {[regexp $Url(fsSep) $part]} {
	    error "URL components cannot include $Url(fsSep)"
	}
	switch -- $part {
	    .  { }
	    .. {
		set len [llength $pathlist]
		if {[incr len -1] < 0} {
		    error "URL out of range"
		}
		set pathlist [lrange $pathlist 0 [incr len -1]]
	    }
	    default {
		lappend pathlist $part
	    }
	}
    }
    return $pathlist
}

proc Url_PostHook {sock length} {
    global Url

    # Backdoor hack for Url_DecodeQuery compatibility
    # We remember the current connection so that Url_DecodeQuery
    # can read the post data if it has not already be read by
    # the time it is called.

    set Url(sock) $sock
    set Url(postlength) $length
}

# convert a x-www-urlencoded string into a list of name/value pairs

proc Url_DecodeQuery {query args} {
    global Url

    if {[info exist Url(postlength)] && ($Url(postlength) > 0)} {
	
	# For compatibility with older versions of the Httpd module
	# that used to read all the post data for us, we read it now
	# if it hasn't already been read

	if {[string length $query]} {
	    append query &
	}
	while {$Url(postlength) > 0} {
	    set Url(postlength) [Httpd_GetPostData $Url(sock) query]
	}
	unset Url(postlength)
    }
    eval {Url_DecodeQueryOnly $query} $args
}

proc Url_DecodeQueryOnly {query args} {

    array set options {-type application/x-www-urlencoded -qualifiers {}}
    catch {array set options $args}
    if {[string length [info command Url_DecodeQuery_$options(-type)]] == 0} {
	set options(-type) application/x-www-urlencoded
    }
    return [Url_DecodeQuery_$options(-type) $query $options(-qualifiers)]
}

proc Url_DecodeQuery_application/x-www-urlencoded {query qualifiers} {

    # These foreach loops are structured this way to ensure there are matched
    # name/value pairs.  Sometimes query data gets garbled.

    set result {}
    foreach pair [split $query "&"] {
	foreach {name value} [split $pair "="] {
	    lappend result [Url_Decode $name] [Url_Decode $value]
	}
    }
    return $result
}
proc Url_Decode {data} {
    regsub -all {\+} $data " " data
    regsub -all {([][$\\])} $data {\\\1} data
    regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
    return [subst $data]
}
if 0 {
    proc UrlDecodeData {data} {
	regsub -all {([][$\\])} $data {\\\1} data
	regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
	return [subst $data]
    }
}


# Sharing procedure bodies doesn't work with compiled procs,
# so these call each other instead of doing
# proc xprime [info args x] [info body x]

proc Url_DecodeQuery_application/x-www-form-urlencoded {query qualifiers} {
    Url_DecodeQuery_application/x-www-urlencoded $query $qualifiers
}

# steve: 5/8/98: This is a very crude start at parsing MIME documents
# Return filename/content pairs
proc Url_DecodeQuery_multipart/form-data {query qualifiers} {

    array set options {}
    catch {array set options $qualifiers}
    if {![info exists options(boundary)]} {
	return -code error "no boundary given for multipart document"
    }

    # Filter query into a list
    # Protect Tcl special characters
    regsub -all {([\\{}])} $query {\\\\\\1} query
    regsub -all -- "(\r?\n?--)?$options(boundary)\r?\n?" $query "\} \{" data
    set data [subst -nocommands -novariables "\{$data\}"]

    # Remove first and last list elements, which will be empty
    set data [lrange [lreplace $data end end] 1 end]

    set result {}
    foreach element $data {

	# Get the headers from the element.  Look for the first empty line.
	set headers {}
	set elementData {}
	# Protect Tcl special characters
	regsub -all {([\\{}])} $element {\\\\\\1} element
	regsub \r?\n\r?\n $element "\} \{" element

	foreach {headers elementData} [subst -nocommands -novariables "\{$element\}"] break

	set headerList {}
	set parameterName {}
	regsub -all \r $headers {} headers
	foreach hdr [split $headers \n] {

	    if {[string length $hdr]} {

		set headerName {}
		set headerData {}
		if {![regexp {[ 	]*([^: 	]+)[ 	]*:[ 	]*(.*)} $hdr discard headerName headerData]} {
		    return -code error "malformed MIME header \"$hdr\""
		}

		set headerName [string tolower $headerName]
		foreach {major minor quals} [Url_DecodeMIMEField $headerData] break

		switch -glob -- [string compare content-disposition $headerName],[string compare form-data $major] {

		    0,0 {

			# This is the name for this query parameter

			catch {unset param}
			array set param $quals
			set parameterName $param(name)

			# Include the remaining parameters, if any
			unset param(name)
			if {[llength [array names param]]} {
			    lappend headerList [list $headerName $major [array get param]]
			}

		    }

		    default {

			lappend headerList [list $headerName $major/$minor $quals]

		    }

		}

	    } else {
		break
	    }
	}
	lappend result $parameterName [list $headerList $elementData]
    }

    return $result
}

# Decode a MIME type
# This could possibly move into the MIME module

proc Url_DecodeMIMEField type {
    set qualList {}
    if {[regexp {([^;]+)[ 	]*;[ 	]*(.+)} $type discard type qualifiers]} {
	foreach qualifier [split $qualifiers ;] {
	    if {[regexp {[ 	]*([^=]+)="([^"]*)"} $qualifier discard name value]} {
	    } elseif {[regexp {[ 	]*([^=]+)='([^']*)'} $qualifier discard name value]} {
	    } elseif {[regexp {[ 	]*([^=]+)=([^ 	]*)} $qualifier discard name value]} {
	    } else {
		continue
	    }
	    lappend qualList $name $value
	}
    }
    foreach {major minor} [split $type /] break
    return [list [string trim $major] [string trim $minor] $qualList]
}

# do x-www-urlencoded character mapping
# The spec says: "non-alphanumeric characters are replaced by '%HH'"
 
for {set i 1} {$i <= 256} {incr i} {
    set c [format %c $i]
    if {![string match \[a-zA-Z0-9\] $c]} {
        set UrlEncodeMap($c) %[format %.2x $i]
    }
}
 
# These are handled specially
array set UrlEncodeMap {
    " " +   \n %0d%0a
}
 
# 1 leave alphanumerics characters alone
# 2 Convert every other character to an array lookup
# 3 Escape constructs that are "special" to the tcl parser
# 4 "subst" the result, doing all the array substitutions
 
proc Url_Encode {string} {
    global UrlEncodeMap 
    regsub -all \[^a-zA-Z0-9\] $string {$UrlEncodeMap(&)} string
    regsub -all \n $string {\\n} string
    regsub -all \t $string {\\t} string
    regsub -all {[][{})\\]\)} $string {\\&} string
    return [subst $string]
}
 
# Register a new location for a URL

proc Url_Redirect {url location} {
    global UrlCache
    set UrlCache($url) [list Httpd_Redirect $location]
}
proc Url_RedirectSelf {url location} {
    global UrlCache
    set UrlCache($url) [list Httpd_RedirectSelf $location]
}
