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

package provide url 1.0

# Hack for file name parsing support
if {$tcl_platform(platform) == "macintosh"} {
    set Url(fsSep) :
} else {
    set Url(fsSep) /
}

# Dispatch to a type-specific handler for a URL

proc Url_Dispatch {sock} {
    global Url UrlCache
    upvar #0 Httpd$sock data

    catch {after cancel $data(cancel)}

    # Note - figure out security policy key for cache index.

    regsub -nocase  {(^http://[^/]+)?} $data(url) {} url

    # Dispatch to cached handler for the URL, if any
    if {(![info exists data(query)] || [string length $data(query)] == 0) \
	    && [info exists UrlCache($url)]} {
	Count cachehit,$url
	if {[catch {
	    eval $UrlCache($url) {$sock}
	}]} {
	    catch {Url_UnCache $sock}
	} else {
	    return
	}
    }
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
	eval $Url(command,$prefix) {$sock $suffix}
    } error]

    if {$code != 0} {
	global errorInfo
	global errorCode

	# URL implementations can raise an error and put redirect info
	# into the errorCode variable, which should be of the form
	# HTTPD_REDIRECT $newurl

	set key [lindex $errorCode 0]
	if {[string match HTTPD_REDIRECT $key]} {
	    Httpd_Redirect [lindex $errorCode 1] $sock
	    return
	}

	switch -glob -- $error {
	    "*can not find channel*"  {
		Httpd_SockClose $sock 1 $error
	    }
	    "too many open files" {
		# this is lame and probably not necessary.
		# Early bugs lead to file descriptor leaks, but
		# these are all plugged up.
		Count numfiles
		Httpd_SockClose $sock 1 $error
		File_Reset
	    } 
	    default {
		Doc_Error $sock $errorInfo
	    }
	}
    }
}

# Declare that a handler exists for a point in the URL tree
# identified by the prefix of all URLs below that point.

proc Url_PrefixInstall {prefix command} {
    global Url

    # Add the url to the prefixset, which is a regular expression used
    # to pick off the prefix from the URL
    # NOTE - ought to denature prefix to avoid regexp specials

    if {[string compare $prefix "/"] == 0} {
	# / is not in the prefixset because of some special cases.
	# See Url_Dispatch
    } elseif {![info exists Url(prefixset)]} {
	set Url(prefixset) $prefix
    } else {
	set list [split $Url(prefixset) |]
	if {[lsearch $list $prefix] < 0} {
	    lappend list $prefix
	}
	set Url(prefixset) [join [lsort -command UrlSort $list] |]
    }
    set Url(command,$prefix) $command
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
    Count cachehit,$data(url)
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
	    continue
	}
	set part [Url_Decode $part]
	# Disallow Mac and UNIX path separators in components
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

# convert a x-www-urlencoded string into a list of name/value pairs

proc Url_DecodeQuery {query args} {
    array set options {-type application/x-www-urlencoded -qualifiers {}}
    catch {array set options $args}
    if {[string length [info command Url_DecodeQuery_$options(-type)]] == 0} {
	set options(-type) application/x-www-urlencoded
    }
    return [Url_DecodeQuery_$options(-type) $query $options(-qualifiers)]
}

proc Url_DecodeQuery_application/x-www-urlencoded {query qualifiers} {
    regsub -all {\+} $query " " query
    set result {}

    # These foreach loops are structured this way to ensure there are matched
    # name/value pairs.  Sometimes query data gets garbled.

    foreach pair [split $query "&"] {
	foreach {name value} [split $pair "="] {
	    lappend result [UrlDecodeData $name] [UrlDecodeData $value]
	}
    }
    return $result
}
proc UrlDecodeData {data} {
    regsub -all {([][$\\])} $data {\\\1} data
    regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
    return [subst $data]
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

proc Url_Decode {data} {
    regsub -all {\+} $data " " data
    regsub -all {([][$\\])} $data {\\\1} data
    regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
    return [subst $data]
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
