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
	if [catch {
	    eval $UrlCache($url) {$sock}
	}] {
	    catch {Url_UnCache $sock}
	} else {
	    return
	}
    }
    # Prefix match the URL to get a domain handler
    if [catch {
	regexp ^($Url(prefixset))(.*) $url x prefix suffix
	eval $Url(command,$prefix) {$sock $suffix}
    } error] {
	global errorInfo

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
		File_Reset $sock $error
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
    # NOTE - ought to denature prefix to avoid regexp specials
    if ![info exists Url(prefixset)] {
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
	set part [Url_Decode $part]
	# Disallow Mac and UNIX path separators in components
	if [regexp $Url(fsSep) $part] {
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

proc Url_DecodeQuery {query} {
    regsub -all {\+} $query " " query
    set result {}
    foreach data [split $query "&="] {
	regsub -all {([][$\\])} $data {\\\1} data
	regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
	lappend result [subst $data]
    }
    return $result
}

proc Url_Decode {data} {
    regsub -all {\+} $data " " data
    regsub -all {([][$\\])} $data {\\\1} data
    regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
    return [subst $data]
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
