# subst.tcl
#@c Subst support
#
# Derived from doc.tcl
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# Colin McCormack (c) 2002
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: subst.tcl,v 1.1.2.1 2002/08/04 01:25:19 coldstore Exp $

package provide httpd::subst 1.0

# Subst_ReturnFile --
#
# Subst a file and return the result to the HTTP client.
# Note that ReturnData has no Modification-Date so the result is not cached.
#
# Arguments:
#	sock	The socket connection.
#	path	The template file pathname.
#	interp 	The Tcl intepreter in which to subst.
#
# Results:
#	None
#
# Side Effects:
#	Returns a page to the client.

proc Subst_ReturnFile {sock path {interp {}}} {
    Httpd_ReturnData $sock text/html [Subst_File $path $interp]
}

# Subst_File --
#
# Subst a file in an interpreter context
#
# Arguments:
#	path	The file pathname of the template.
#	interp  The interpreter in which to subst.
#
# Results:
#	The subst'ed page.
#
# Side Effects:
#	None

proc Subst_File {path {interp {}}} {

    set in [open $path]
    set script [read $in]
    close $in

    if {[string length $interp] == 0} {
	set result [uplevel #0 [list subst $script]]
    } else {
	set result [interp eval $interp [list subst $script]]
    }
    return $result
}

# Doc_application/x-tcl-auth --
#
# Like tcl-subst, but a basic authentication cookie is used for session state
#
# Arguments:
#	path	The file pathname.
#	suffix	The URL suffix.
#	sock	The socket connection.
#
# Results:
#	None
#
# Side Effects:
#	Returns a page to the client.

proc Doc_application/x-tcl-auth {path suffix sock} {
    upvar #0 Httpd$sock data

    if {![info exists data(session)]} {
	Httpd_RequestAuth $sock Basic "Random Password"
	return
    }
    set interp [Session_Authorized $data(session)]

    # Need to make everything look like a GET so the Cgi parser
    # doesn't read post data from stdin.  We've already read it.

    set data(proto) GET

    Doc_application/x-tcl-subst
}

# Doc_application/x-tcl-subst --
#
# Tcl-subst a template that mixes HTML and Tcl.
# This subst is just done in the context of the specified
# interpreter with not much other support.
# See x-tcl-template for something more sophisticated
#
# Arguments:
#	path	The file pathname.
#	suffix	The URL suffix.
#	sock	The socket connection.
#	interp	The interp to use for subst'ing.
#
# Results:
#	None
#
# Side Effects:
#	Sets the env array in interp and calls Subst_ReturnFile.

proc Doc_application/x-tcl-subst {path suffix sock {interp {}}} {
    upvar #0 Httpd$sock data

    Cgi_SetEnv	$sock $path pass
    interp eval $interp [list uplevel #0 [list array set env [array get pass]]]
    Subst_ReturnFile $sock $path $interp
}

