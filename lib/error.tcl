# error.tcl
#@c handlers for server errors and doc-not-found cases.
#
#
# Derived from doc.tcl
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# Colin McCormack (c) 2002
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: error.tcl,v 1.1.2.2 2002/08/04 02:28:05 coldstore Exp $

package provide httpd::error 1.0

package require httpd::subst

# Error_NotFoundPage --
#
#@c Register a file not found error page.
#@c This page always gets "subst'ed, but without the fancy
#@c context of the ".tml" pages.
#@c
# Arguments:
#@a	virtual	The URL of the not-found page, e.g., /notfound.html
#
# Results:
#@r	None
#
# Side Effects:
#@e	Sets the not-found page.

proc Error_NotFoundPage { virtual } {
    global Error
    set Error(notfound) [Doc_Virtual {} {} $virtual]
}

# Error_ErrorPage --
#
#@c Register a server error page.
#@c This page always gets "subst'ed"
#
# Arguments:
#@a	virtual	The URL of the error page, e.g., /error.html
#
# Results:
#@r	None
#
# Side Effects:
#@e	Sets the error page.

proc Error_ErrorPage { virtual } {
    global Error
    set Error(error) [Doc_Virtual {} {} $virtual]
}

# Error_NotFound --
#
#@c	Called when a page is missing.  This looks for a handler page
#@c	and sets up a small amount of context for it.
#
# Arguments:
#@a	sock	The socket connection.
#
# Results:
#@r	None
#
# Side Effects:
#@e	Returns a page.

proc Error_NotFound { sock } {
    global Error Referer
    upvar #0 Httpd$sock data
    CountName $data(url) notfound
    set Error(url,notfound) $data(url)	;# For subst
    if {[info exists data(mime,referer)]} {

	# Record the referring URL so we can track down
	# bad links

	lappendOnce Referer($data(url)) $data(mime,referer)
    }
    ErrorSubstSystemFile $sock notfound 404 [protect_text $Error(url,notfound)]
}

# Error_Error --
#
#@c	Called when an error has occurred processing the page.
#
# Arguments:
#@a	sock	The socket connection.
#	ei	errorInfo
#
# Results:
#@r	None
#
# Side Effects:
#@e	Returns a page.

proc Error_Error { sock ei } {
    global Error
    upvar #0 Httpd$sock data
    set Error(errorUrl) $data(url)
    set Error(errorInfo) $ei	;# For subst
    CountName $Error(errorUrl) errors
    ErrorSubstSystemFile $sock error 500 [protect_text $ei]
}

# ErrorSubstSystemFile --
#
#	Simple template processor for notfound and error pages.
#
# Arguments:
#	sock	The socket connection
#	key	Either "notfound" or "error"
#	code	HTTP code
#	extra 	Optional string to include in return page.
#	interp  Interp to use for Subst.
#
# Results:
#	None
#
# Side Effects:
#	Returns a page.

proc ErrorSubstSystemFile {sock key code {extra {}} {interp {}}} {
    global Error env
    if {![info exists Error(page,$key)]} {
	set path [Doc_Virtual {} {} /$key.html]
	if {[file exists $path]} {
	    set Error(page,$key) $path
	}
    }
    if {![info exists Error(page,$key)] || 
	[catch {Subst_ReturnFile $sock $Error(page,$key) $interp} err]} {
	if {[info exists err]} {
	    Log $sock ErrorSubstSystemFile $err
	}
	Httpd_Error $sock $code $extra
    }
}
