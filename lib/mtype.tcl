# mimetype.tcl --
# Code to deal with mime types
#
# Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) mtype.tcl 1.8 97/06/26 15:10:28

package provide mtype 1.0

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

    catch {unset MimeType}
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

