# template.tcl
#@c Template support
#
# Derived from doc.tcl
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: template.tcl,v 1.19 2004/09/05 05:10:14 coldstore Exp $

package provide httpd::template 1.0

package require httpd	;# Httpd_PostDataSize Httpd_ReturnData
package require httpd::cgi	;# Cgi_SetEnv Cgi_SetEnvInterp
package require httpd::cookie	;# Cookie_Save
package require httpd::doc	;# Doc_GetPath
package require httpd::log	;# Log
package require httpd::mtype	;# Mtype
package require httpd::subst	;# Subst_File
package require httpd::url	;# Url_Decode Url_DecodeQuery Url_ReadPost
package require httpd::utils	;# file file_latest lappendOnce

# Set the file extension for templates

if {![info exists Template(tmlExt)]} {
    set Template(tmlExt) .tml
}
if {![info exists Template(env)]} {
    set Template(env) 1
}

if {![info exists Template(htmlExt)]} {
    switch $tcl_platform(platform) {
	windows {
	    set Template(htmlExt) .htm
	}
	default {
	    set Template(htmlExt) .html
	}
    }
}

set Template(htmlMatch) {([.]html?)}

# Template_Check --
#
# Allow or disable automatic template checking
#
# Arguments:
#	how 	A boolen that enables or disables template handling.
#
# Results:
#	None
#
# Side Effects:
#	Sets the checkTemplates variable.

proc Template_Check {{how 1}} {
    global Template
    set Template(checkTemplates) $how
}
if {![info exists Template(checkTemplates)]} {
    set Template(checkTemplates) 0
}

# Template_Interp --
#
# Choose an alternate interpreter in which to process templates
#
# Arguments:
#	interp	The Tcl interpreter in which to process templates.
#
# Results:
#	None
#
# Side Effects:
#	Sets the interpreter for all Doc domain templates.

proc Template_Interp {interp} {
    global Template
    if {[string length $interp] && ![interp exists $interp]} {
	interp create $interp
    }
    set Template(templateInterp) $interp
}
if {![info exists Template(templateInterp)]} {
    set Template(templateInterp) {}
}

# Template_Library --
#
# Define the auto_load library for template support
#
# Arguments:
#	dir	The directory to add to the auto_path
#
# Results:
#	None
#
# Side Effects:
#	Updates the auto_path variable in the interpreter used
#	for templates.

proc Template_Library {dir} {
    global Template auto_path
    set Template(templateLibrary) $dir
    if {$Template(templateInterp) != {}} {
	interp eval $Template(templateInterp) [list lappendOnce ::auto_path $dir]
    } else {
	lappendOnce auto_path $dir
    }
}

# Doc_application/x-tcl-template --
#
# Tcl-subst a template that mixes HTML and Tcl.
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
#	Sets up the interpreter context and subst's the page,
#	which is returned to the client.

proc Doc_application/x-tcl-template {path suffix sock} {
    upvar #0 Httpd$sock data
    global Template

    # This is always dynamic (ReturnData has no modification date)
    # so the result is not cached at the remote end, nor is a local
    # .html file cached.

    set content [TemplateInstantiate $sock $path {} $suffix {} $Template(templateInterp)]
    # If the content type was set, use it.  Otherwise, use the default.
    if {[info exists data(contentType)]} {
	set ctype $data(contentType)
    } else {
	set ctype text/html
    }
    return [Httpd_ReturnData $sock $ctype $content]
}

# TemplateInstantiate --
#
# Generate a .html file from a template
# and from any .tml files in directories leading up to the root.
# The processing is done in the specified interpreter.
# State set in the global array "page":
#	url		The URL past the document root
#	template	The filename of the template file
#	filename	The filename of the associated htmlfile
#	root		The ../ path up to the root
#	dynamic		If 1, then this page is dynamically generated
#			on every fetch.  Otherwise the page has a cached
#			static representation.
#
# Arguments:
#	sock		The client socket.
#	template	The file name of the template.
#	htmlfile	The file name of the corresponding .html file.
#	suffix		The URL suffix.
#	dynamicVar	Name of var to set to dynamic property of the page.
#	interp		The interp to use for substing.
#
# Results:
#	html, or an error generated by the template
#
# Side Effects:
#	Generates a page.  Will set up the CGI environment via the ncgi
#	module, and will do environment variable settings.
#	data(contentType) contains the mime type of generated content.

proc TemplateInstantiate {sock template htmlfile suffix dynamicVar {interp {}}} {
    upvar #0 Httpd$sock data
    upvar $dynamicVar dynamic
    global Template

    # Compute a relative path back to the root.

    set dirs [lreplace [split [string trimleft $data(url) /] /] end end]
    set root ""
    foreach d $dirs {
	append root ../
    }

    # Populate the global "page" array with state about this page
    if {[string length $htmlfile]} {
	set filename $htmlfile
	set dynamic 0
    } else {
	set filename $template
	set dynamic 1
    }
    interp eval $interp {uplevel #0 {catch {unset page}}}

    interp eval $interp [list uplevel #0 [list array set page [list \
	url		$data(url)	\
	template 	$template	\
	includeStack 	[list [file dirname $template]]	\
	filename	$filename	\
	root		$root		\
	dynamic		$dynamic	\
    ]]]

    # Populate the global "env" array similarly to the CGI environment
    if {$Template(env)} {
	Cgi_SetEnvInterp $sock $filename $interp
    }

    # Check query data.

    if {[Httpd_PostDataSize $sock] > 0 && ![info exists data(query)]} {
	set data(query) {}
    }
    if {[info exist data(query)]} {
	if {![info exist data(mime,content-type)] || $data(proto) == "GET"} {
	    
	    # The check against GET is because IE 5 has the following bug.
	    # If it does a POST with content-type multipart/form-data and
	    # keep-alive reuses the connection for a subsequent GET request,
	    # then the GET request erroneously has a content-type header
	    # that is a copy of the one from the previous POST!

	    set type application/x-www-urlencoded
	} else {
	    set type $data(mime,content-type)
	}

	# Read and append the pending post data to data(query).

	Url_ReadPost $sock data(query)

	# Initialize the Standard Tcl Library ncgi package so its
	# ncgi::value can be used to get the data.  This replaces
	# the old Url_DecodeQuery interface.

	interp eval $interp [list ncgi::reset $data(query) $type]
	interp eval $interp [list ncgi::parse]
	interp eval $interp [list ncgi::urlStub $data(url)]

	# Define page(query) and page(querytype)
	# for compatibility with older versions of TclHttpd
	# This is a bit hideous because it reaches inside ::ncgi
	# to avoid parsing the data twice.

	interp eval $interp [list uplevel #0 [list set page(querytype) \
		[string trim [lindex [split $type \;] 0]]]]
	interp eval $interp [list uplevel #0 {
	    set page(query) {}
	    foreach n $ncgi::varlist {
		foreach v $ncgi::value($n) {
		    lappend page(query) $n $v
		}
	    }
	}]

    } else {
	interp eval $interp [list ncgi::reset ""]
	interp eval $interp [list uplevel #0 [list set page(query) {}]]
	interp eval $interp [list uplevel #0 [list set page(querytype) {}]]
    }

    # Source the .tml files from the root downward.

    foreach libdir [Doc_GetPath $sock $template] {
	set libfile [file join $libdir $Template(tmlExt)]
	if {[file exists $libfile]} {
	    interp eval $interp [list uplevel #0 [list source $libfile]]
	}
    }

    # Process the template itself

    set code [catch {Subst_File $template $interp} html]

    if {$code != 0} {
	# pass errors up - specifically Redirect return code

	# stash error information so Cookie_Save doesn't interfere
	global errorCode errorInfo
	set ec $errorCode
	set ei $errorInfo

	# Save return cookies, if any
	Cookie_Save $sock $interp

	return -code $code -errorcode $ec -errorinfo $ei
    }

    # Save return cookies, if any
    Cookie_Save $sock $interp

    set dynamic [interp eval $interp {uplevel #0 {set page(dynamic)}}]
    if {!$dynamic} {

	# Cache the result

	catch {file delete -force $htmlfile}

	# process any filters
	if {[info exists data(filter)]} {
	    while {[llength $data(filter)]} {
		set cmd [lindex $data(filter) end]
		set data(filter) [lrange $data(filter) 0 end-1]
		catch {
		    set html [eval $cmd $sock [list $html]]
		}
	    }
	}

	if {[catch {open  $htmlfile w} out]} {
	    set dynamic 1
	    Log $sock "Template" "no write permission"
	} else {
	    puts -nonewline $out $html
	    close $out
	}
    }
    return $html
}

# Template_Dynamic
#	Supress generation of HTML cache
#
# Arguments:
#
# Results:
#	None
#
# Side Effects:
#	Sets the dynamic bit so the page is not cached.

proc Template_Dynamic {} {
    global page
    set page(dynamic) 1
    return "<!-- DynamicOnly -->\n"
}

# TemplateCheck --
#
# Check modify times on all templates that affect a page
#
# Arguments:
#	sock		The client connection
#	template	The file pathname of the template.
#	htmlfile	The file pathname of the cached .html file.
#
# Results:
#	1 if the template or any dependent .tml file are newer than
#	the cached .html file.
#
# Side Effects:
#	None

proc TemplateCheck {sock template htmlfile} {
    global Template

    if {[file exists $htmlfile]} {
	set mtime [file mtime $htmlfile]
    } else {
	return 1
    }

    # Look for .tml library files down the hierarchy.
    global Doc
    set rlen [llength [file split $Doc(root)]]
    set dirs [lrange [file split [file dirname $template]] $rlen end]
	
    foreach libdir [Doc_GetPath $sock $template] {
	set libfile [file join $libdir $Template(tmlExt)]
	if {[file exists $libfile] && ([file mtime $libfile] > $mtime)} {
	    return 1
	}
    }

    # make index.html regeneration depend upon the whole directory's
    # modification time, not just the modification time of index.tml
    global dirlist
    if {[file root [file tail $htmlfile]] == [file root $dirlist(indexpat)]} {
	if {[file mtime [file dirname $htmlfile]] > $mtime} {
	    return 1
	}
    }

    return [expr {[file mtime $template] > $mtime}]
}


# Template_try --
# process a template file which is newer than the path (if path exists).
#
# Arguments:
#	sock	The client connection
#	prefix	The URL prefix of the domain.
#	path	The file system pathname of the file.
#	suffix	The URL suffix.
#
# Results:
#	1 if the request has been completed (by a dynamic template)
#	0 if the request hasn't been handled, either because there is
#	  no template, or because cache file is (now) newer and can be
#	  handled by caller
#
# Side Effects:
#	May have generated a page - 
#	data(contentType) contains the mime type of generated content.

proc Template_Try {sock path prefix suffix} {
    upvar #0 Httpd$sock data
    global Template

    if {!$Template(checkTemplates)} {
	return 0
    }

    set template ${path}$Template(tmlExt)

    if {![file exists $template]} {
	# special case, x.tml generates x.html
	set template [file root $path]$Template(tmlExt)
	
	# ensure request was for *.htm[l]? and .tml exists
	if {![regexp $Template(htmlMatch) [file extension $path]]
	    || ![file exists $template]} {
	    # no template found
	    return 0
	}
    }

    # we have a matching template and extension for path
    # See if the cached result is up-to-date
    if {[TemplateCheck $sock $template $path]} {
	# Template file is newer than its cached version
	# Do the subst and cache the result in the .html file
        # We set a provisional type based on the file extension, but
        # the template processing can override that
        set data(contentType) [Mtype $path]
	set html [TemplateInstantiate $sock $template $path $suffix dynamic \
		      $Template(templateInterp)]

	if {$dynamic} {
	    # return the data directly
	    Httpd_ReturnData $sock $data(contentType) $html
	    return 1
	} else {
	    # we have generated a cached file from the template.
	    # leave it to caller to return newly generated file
	    return 0
	}
    } else {
	# cache file is newer
	return 0
    }
}

# Template_Choose - what mime-type does this file
# represent, or generate?
# a.x.tml is considered to return/match .x
proc Template_Choose {accept choices} {
    global Template

    # generate a map map from mime_type -> choices
    foreach f $choices {
	# get first of two extensions eg .css.tml
	set type [file extension [file root $f]]	;# use .css in .css.tml
	if {$type == ""} {
	    set type [file extension $f]	;# path has only a single extension
	    if {$type == $Template(tmlExt)} {
		# we've found a .tml file - x.tml matches x.html
		set type $Template(htmlExt)
	    }
	}
	lappend mtype([Mtype $type]) $f
    }

    # array mtype is now a mapping from mime types to files
    # for the collection of files we can offer.

    # look at what mime types the client accepts, in order of presentation
    # (nb FIXME: the spec says we should accept them in q= order)
    foreach t [split $accept ,] {
	# find something that matches 
	regsub {;.*} $t {} t	;# Nuke quality parameters
	set t [string trim [string tolower $t]]

	# collect string-matching mtypes we can offer
	set hits {}
	foreach {mime files} [array get mtype $t] {
            set hits [concat $hits $files]
	}

	# if some file choices match on type, choose the most recent
	if {[llength $hits] > 1} {
	    set hit [file_latest $hits]
	} else {
	    set hit [lindex $hits 0]
	}

	if {[string length $hit]} {
	    # we have a matching file
	    if {[file extension $hit] == $Template(tmlExt)} {
		# our candidate is a template file
		# return the name of the file as it will be.
		if {[file extension [file root $hit]] == ""} {
		    # we're about to offer a .tml - as an .html
		    return "[file root $hit]$Template(htmlExt)"
		} else {
		    # strip the .tml and return for redirection
		    return [file root $hit]
		}
	    }
	    return $hit	;# not a templated match
	}
    }

    return {}	;# no acceptable matches
}
