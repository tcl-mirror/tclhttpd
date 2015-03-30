# fallback.tcl
#@c Fallback does "content negotation" if a file isn't found
#@c look around for files with different suffixes but the same root.
#
# NOTE: This feature is probably more trouble than it is worth.
# It was originally used to be able to choose between different
# iamge types (e.g., .gif and .jpg), but is now also used to
# find templates (.tml files) that correspond to .html files.
#
#
# Derived from doc.tcl
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: fallback.tcl,v 1.8 2004/09/05 05:10:14 coldstore Exp $

package provide httpd::fallback 1.0

package require httpd::mtype	;# Mtype Mtype_Accept
package require httpd::redirect	;# Redirect_QuerySelf
package require httpd::template	;# Template_Choose
#package require httpd::utils	;# file

# Fallback_ExcludePat --
#
# Define a pattern of files names to exclude in Fallback
#
# Arguments:
#	patlist	A glob pattern of files to avoid when playing
#		games in FallBack to find an alternative file.
#
# Results:
#	None
#
# Side Effects:
#	Sets the exclude pattern.

proc Fallback_ExcludePat {patlist} {
    global Fallback
    set Fallback(excludePat) $patlist
}
if {![info exists Fallback(excludePat)]} {
    set Fallback(excludePat) {*.bak *.swp *~}
}

# Fallback_Try
#
# Try to find an file which matches the HTTP Accept alternatives
# given by the client.
#
# Arguments:
#	prefix	The URL prefix of the domain.
#	path	The pathname we were trying to find.
#	suffix	The URL suffix.
#	sock	The socket connection.
#
# Results:
#	None
#
# Side Effects:
#	This either triggers an HTTP redirect to switch the user
#	to the correct file name, or it calls out to the template-aware
#	text/html processor.

proc Fallback_Try {virtual path suffix sock} {
    set root [file root $path]
    if {[string match */ $root]} {
	# Input is something like /a/b/.xyz
	return 0
    }

    # Look for files indicated by any Accept headers.
    # Most browsers say */*, but they may provide some ordering info, too.

    # First generate a list of candidate files by ignoring extension
    global Template	;# we need the template extension here
    set ok {}
    foreach choice [glob -nocomplain $root.*] {
	# don't let "foo.html.old" match for "foo.html"
	# but let foo.*.tml match for foo.*
	if {[string equal $root [file root $choice]]
	    || [string equal [file extension $choice] $Template(tmlExt)]} {

	    # Filter on the exclude patterns
	    if {![FallbackExclude $choice]} {
		lappend ok $choice
	    }
	}
    }

    # Now we pick the best file from the files and templates that matched
    # Template_Choose will return us the best possible match
    # the best match might not yet exist, but may be able to be generated 
    # from a template, which will be handled after the redirection we provoke
    set npath [Template_Choose [Mtype_Accept $sock] $ok]
    if {[string length $npath] == 0} {
	# there was no viable alternative
	return 0
    } elseif {[string compare $path $npath] == 0} {
	# the best alternative was the original path requested
	# FIXME: this is bogus - we shouldn't even be called if there's a match
	return 0
    } else {
	# A file matched with a different extension to that requested
	# (if the match was a template, we offer the untemplated name.)

	# Redirect_to/offer our best match.
	# Redirect so we don't mask spelling errors like john.osterhoot

	set new [file extension $npath]	;# candidate extension
	set old [file extension $suffix]	;# requested extension
	if {[string length $old] == 0} {
	    append suffix $new	;# client request was without extension
	} else {
	    # client requested foo.$old, we're offering foo.$new
	    # Watch out for specials in $old, like .html)
	    # FIXME: the following seems bogus and heavyweight
	    # if there's an element in the path which happens to match the ext,
	    # we will subst it too, which can't be a good thing.
	    # we should really decompose the path and reconstruct it.
	    regsub -all {[][$^|().*+?\\]} $old {\\&} old ;# quote special chars
	    regsub $old\$ $suffix $new suffix	;# substitute $new for $old
	}

	# Offer alternative to the client by redirection, preserving query data
	Redirect_QuerySelf $sock "$virtual[string trimleft $suffix /~]"
	return 1	;# we have completely handled the request.
    }
}

# FallbackExclude --
#
# This is used to filter out files like "foo.bak"  and foo~
# from the Fallback failover code
#
# Arguments:
#	name	The filename to filter.
#
# Results:
#	1	If the file should be excluded, 0 otherwise.
#
# Side Effects:
#	None

proc FallbackExclude {name} {
    global Fallback
    foreach pat $Fallback(excludePat) {
	if {[string match $pat $name]} {
	    return 1
	}
    }
    return 0
}
