# mimetype.tcl --
# Code to deal with mime types
#
# Brent Welch (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: mtype.tcl,v 1.4.6.1 2002/08/28 02:43:06 welch Exp $

package provide httpd::mtype 1.1

# Convert the file suffix into a mime type

proc Mtype {path} {
    global MimeType

    set ext [string tolower [file extension $path]]
    if {[info exist MimeType($ext)]} {
	return $MimeType($ext)
    } else {
	return text/plain
    }
}

# Read a mime types file into the mimeType array.
# Set up some minimal defaults if no file is available.

proc Mtype_ReadTypes {file} {
    global MimeType

    array set MimeType {
	{}	text/plain
	.txt	text/plain
	.htm	text/html
	.html	text/html
	.tml	application/x-tcl-template
	.gif	image/gif
	.thtml	application/x-safetcl
	.shtml	application/x-server-include
	.cgi	application/x-cgi
	.map	application/x-imagemap
	.subst	application/x-tcl-subst
    }
    if [catch {open $file} in] {
	return
    }

    while {[gets $in line] >= 0} {
	if [regexp {^( 	)*$} $line] {
	    continue
	}
	if [regexp {^( 	)*#} $line] {
	    continue
	}
	if [regexp {([^ 	]+)[ 	]+(.+)$} $line match type rest] {
	    foreach item [split $rest] {
		if [string length $item] {
		    set MimeType([string tolower .$item]) $type
		}
	    }
	}
    }
    close $in
}

proc Mtype_Add {suffix type} {
    global MimeType

    set suffix [string trimleft $suffix .]
    set MimeType([string tolower .$suffix]) $type
}

proc Mtype_Reset {} {
    global MimeType
    if {[info exist MimeType]} {
        unset MimeType
    }
}
