# direct.tcl
#
# Support for application-direct URLs that result in Tcl procedures
# being invoked inside the server.
#
# Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) direct.tcl 1.7 97/06/26 15:10:56

package provide direct 1.0

# Define a subtree of the URL hierarchy that is implemented by
# direct Tcl calls.
# virtual: The name of the subtree of the hierarchy, e.g., /device
# prefix: The Tcl command prefix to use when constructing calls, e.g. Device

proc Direct_Url {virtual {prefix {}}} {
    if {[string length $prefix] == 0} {
	set prefix $virtual
    }
    Url_PrefixInstall $virtual [list DirectDomain $prefix]
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
    set valuelist {}
    if [info exists data(query)] {
	# Parse form parameters into the cgi array
	# If the parameter is listed twice, the array becomes a list
	# of the values.
	set valuelist [Url_DecodeQuery $data(query)]
	foreach {name value} $valuelist {
	    if [info exists list($name)] {
		set cgi($name) [list $cgi($name) $value]
		unset list($name)
	    } elseif [info exists cgi($name)] {
		lappend cgi($name) $value
	    } else {
		set cgi($name) $value
		set list($name) 1	;# Need to listify if more values are added
	    }
	}
    }
    set cmd $prefix$suffix
    if {![iscommand $cmd]} {
	Httpd_Error $sock 403
	return
    }
    if {[string length [info command $cmd]] == 0} {
	auto_load $cmd
    }

    # Compare built-in command's parameters with the form data.
    # Form fields with names that match arguments have that value
    # passed for the corresponding argument.
    # Form fields with no corresponding parameter are collected into args.

    set cmdOrig $cmd
    set params [info args $cmdOrig]
    foreach arg $params {
	if ![info exists cgi($arg)] {
	    if [info default $cmdOrig $arg value] {
		lappend cmd $value
	    } elseif {[string compare $arg "args"] == 0} {
		set needargs yes
	    } else {
		lappend cmd {}
	    }
	} else {
	    lappend cmd $cgi($arg)
	}
    }
    if [info exists needargs] {
	foreach {name value} $valuelist {
	    if {[lsearch $params $name] < 0} {
		lappend cmd $name $value
	    }
	}
    }
    # Eval the command.  Errors are trapped by Url_Dispatch

    set result [eval $cmd]

    # See if a content type has been registered for the URL

    set type text/html
    upvar #0 $cmdOrig aType
    catch {set type $aType}
    Httpd_ReturnData $sock $type $result
    return $result
}

