# direct.tcl
#
# Support for application-direct URLs that result in Tcl procedures
# being invoked inside the server.
#
# Brent Welch (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: direct.tcl,v 1.10 2000/09/27 19:35:26 welch Exp $

package provide httpd::direct 1.0

# Direct_Url
#	Define a subtree of the URL hierarchy that is implemented by
#	direct Tcl calls.
#
# Arguments
#	virtual The name of the subtree of the hierarchy, e.g., /device
#	prefix	The Tcl command prefix to use when constructing calls,
#		e.g. Device
#	inThread	True if this should be dispatched to a thread.
#
# Side Effects
#	Register a prefix

proc Direct_Url {virtual {prefix {}} {inThread 0}} {
    global Direct
    if {[string length $prefix] == 0} {
	set prefix $virtual
    }
    set Direct($prefix) $virtual	;# So we can reconstruct URLs
    Url_PrefixInstall $virtual [list DirectDomain $prefix] $inThread
}

# Main handler for Direct domains (i.e. tcl commands)
# prefix: the Tcl command prefix of the domain registered with Direct_Url 
# sock: the socket back to the client
# suffix: the part of the url after the domain prefix.
#
# This calls out to the Tcl procedure named "$prefix$suffix",
# with arguments taken from the form parameters.
# Example:
# Direct_Url /device Device
# if the URL is /device/a/b/c, then the Tcl command to handle it
# should be
# proc Device/a/b/c
# You can define the content type for the results of your procedure by
# defining a global variable with the same name as the procedure:
# set Device/a/b/c text/plain
#  The default type is text/html

proc DirectDomain {prefix sock suffix} {
    global Direct
    upvar #0 Httpd$sock data
    Count $prefix

    # Set up the environment a-la CGI

    global env
    Cgi_SetEnv $sock $prefix$suffix

    set valuelist {}
    if [info exists data(query)] {
	# search for comma separeted pair of numbers
	# as generated from server side map
	#      e.g 190,202
	# Bjorn Ruff.

	if { [regexp {^([0-9]+),([0-9]+)$} $data(query) match x y]} {
	    set data(query) x=$x&y=$y
	}

	# Honor content type of the query data
	# Some browsers leave junk Content-Type lines in
	# non-post requests as a side effect of keep alive.

	if {[info exist data(mime,content-type)] &&
		("$data(proto)" != "GET")} {
	    set type $data(mime,content-type)
	} else {
	    set type application/x-www-urlencoded
	}

	# Grab POST data, if any, and initialize the ncgi:: interface

	Url_ReadPost $sock data(query)
	ncgi::reset $data(query) $type
	ncgi::parse
	ncgi::urlStub $data(url)
    }
    set cmd $prefix$suffix
    if {![iscommand $cmd]} {
	Doc_NotFound $sock
	return
    }
    CountName $data(url) hit

    # Compare built-in command's parameters with the form data.
    # Form fields with names that match arguments have that value
    # passed for the corresponding argument.
    # Form fields with no corresponding parameter are collected into args.

    set cmdOrig $cmd
    set params [info args $cmdOrig]
    foreach arg $params {
	if {[ncgi::empty $arg]} {
	    if [info default $cmdOrig $arg value] {
		lappend cmd $value
	    } elseif {[string compare $arg "args"] == 0} {
		set needargs yes
	    } else {
		lappend cmd {}
	    }
	} else {
	    lappend cmd [ncgi::value $arg]
	}
    }
    if [info exists needargs] {
	foreach {name value} [ncgi::nvlist] {
	    if {[lsearch $params $name] < 0} {
		lappend cmd $name $value
	    }
	}
    }
    # Eval the command.  Errors can be used to trigger redirects.

    set code [catch $cmd result]
    switch $code {
	0	{ # fall through to Httpd_ReturnData }
	302	{ # redirect 
	    Httpd_Redirect $result $sock
	    return ""
	}
	default {
	    global errorInfo errorCode
	    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
	}
    }

    # See if a content type has been registered for the URL

    set type text/html
    upvar #0 $cmdOrig aType
    if {[info exist aType]} {
	set type $aType
    }

    # See if any cookies have been set
    # This works with the Doc_SetCookie procedure that populates
    # the global page array

    global page
    if {[info exist page(set-cookie)]} {
	foreach c $page(set-cookie) {
	    Httpd_SetCookie $sock $c
	}
	unset page(set-cookie)
    }

    Httpd_ReturnData $sock $type $result
    return ""
}
