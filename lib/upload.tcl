# upload.tcl
#
# File upload domain.  This implements a domain handler that
# specializes in file uploading of multipart/form-data.
# It uploads files into a particular directory and enforces
# limits on the number of files, their size, etc.
# It invokes handler procedures similar to application-direct
# handlers after doing the file upload.
#
# Brent Welch (c) 2001
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: upload.tcl,v 1.1 2001/01/29 07:42:46 welch Exp $

package provide httpd::upload 1.0
package require ncgi

# Upload_Url
#	Define a subtree of the URL hierarchy that handles
#	file uploads.
#
# Arguments
#	virtual The URL prefix of the upload domain.
#	dir	The upload directory - files get placed here.	
#	command	The Tcl command to invoke after an upload.
#	args	option-value flags described below.
#		-thread <boolean>
#			If true, dispatch domain in a thread
#		-maxfiles <integer>
#			Maximum files in upload directory
#		-maxbytes <integer>
#			Maximum number of bytes in a file
#		-totalbytes <integer>
#			Limit on total bytes in all files
#			in the upload directory
#
# Side Effects
#	Register a prefix

proc Upload_Url {virtual dir command args} {
    global Upload
    array set opt {
	    -inThread 0
	    -maxfiles -1
	    -maxbytes -1
	    -totalbytes -1
    }
    array set opt $args
    Url_PrefixInstall $virtual [list UploadDomain $dir $command \
	$opt(-maxfiles) $opt(-maxbytes) $opt(-totalbytes)] \
	-thread $opt(-inThread) \
	-readpost 0
}

# UploadDomain
# Main handler for Upload domains 
# This uploads the file, if it does not exceed the byte
# and file limits, then invokes the callback.
#
# Arguments
#	dir	Upload directory
#	cmd	Tcl command to call after upload
#	maxfiles	Max files per upload diretory
#	maxbytes	File byte limit
#	totalbytes	Total bytes per upload directory
#	sock	The socket back to the client
#	suffix	The part of the url after the domain prefix.
#

proc UploadDomain {dir cmd maxfiles maxbytes totalbytes sock suffix} {
    upvar #0 Httpd$sock data
    upvar #0 Upload$sock upload

    # Extract multi-part boundary from the headers

    if {![info exist data(mime,content-type)] || $data(proto) == "GET"} {
	set type application/x-www-urlencoded
    } else {
	set type $data(mime,content-type)
    }
    set parsedType [ncgi::parseMimeValue $type]
    if {![string match multipart/* [lindex $parsedType 0]]} {
	return -code error "Not a multipart Content-Type: [lindex $parsedType 0]"
    }
    array set options [lindex $parsedType 1]
    if {![info exists options(boundary)]} {
	return -code error "No boundary given for multipart document"
    }

    # Record upload instance data and set up a read event handler
    # so we can read large files without blocking.

    set upload(boundary) $options(boundary)
    set upload(dir) $dir
    set upload(cmd) $cmd
    set upload(maxfiles) $maxfiles
    set upload(totalbytes) $totalbytes
    set upload(maxbytes) $maxbytes
    set upload(suffix) $suffix
    set upload(state) header	;# or body

    fconfigure $sock -trans binary
    fileevent $sock readable [list UploadFindBoundary $sock]
}

# Look for the first boundary - should be the first line read,
# but done in a fileevent to avoid blocking.

proc UploadFindBoundary $sock {
    if {[eof $sock]} {
	UploadDone $sock
	return
    }
    if {[gets $sock line] > 0} {
	if {[regexp ^--$upload(boundary) $line]} {
	    fileevent $sock readable [list UploadReadHeader $sock]
	} else {
Stderr "UploadFindBoundary Unexpected line $line"
	}
    }
}

proc UploadReadHeader $sock {
    if {[eof $sock]} {
	UploadDone $sock
	return
    }

    # Read through the POST data line-by-line looking for the
    # boundary and diverting file content into files in the
    # upload directory.  We read in binary mode to preserve whatever
    # line-ending mode is in the uploaded file.


    while {[gets $sock line] >= 0} {
	if {[string length $line] == 0} {
	    # End of headers
	    fileevent $sock readable [list UploadReadPart $sock]
	    return
	}
    }
    if {[fblocked $sock]} {
	return
    }

    # Set up the environment a-la CGI.

    Cgi_SetEnv $sock $prefix$suffix

    # Prepare an argument data from the query data.

    Url_QuerySetup $sock
    set cmd [Direct_MarshallArguments $prefix $suffix]
    if {$cmd == ""} {
	Doc_NotFound $sock
	return
    }

    # Eval the command.  Errors can be used to trigger redirects.

    set code [catch $cmd result]

    set type text/html
    upvar #0 $prefix$suffix aType
    if {[info exist aType]} {
	set type $aType
    }

    DirectRespond $sock $code $result $type
}

# Look for the boundary at the end of a content part.

proc UploadReadPart {sock} {
    if {[eof $sock]} {
	UploadDone $sock
	return
    }
    if {[gets $sock line] > 0} {
	if {[regexp ^--$upload(boundary) $line]} {
	    fileevent $sock readable [list UploadReadHeader $sock]
	} else {

	}
    }
}

# Read a content part and copy it to a file.

proc UploadReadFile {sock fd} {
    if {[eof $sock]} {
	UploadDone $sock
	return
    }
    while {[gets $sock line] >= 0} {
	if {[regexp ^--$upload(boundary) $line]} {
	    close $fd
	    fileevent $sock readable [list UploadReadHeader $sock]
	} else {
	    puts $fd $line
	}
    }
}

proc UploadDone {sock} {
    close $sock
}
