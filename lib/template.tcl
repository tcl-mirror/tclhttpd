# template.tcl
#@c Template support
#
# Derived from doc.tcl
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# Colin McCormack (c) 2002
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: template.tcl,v 1.4 2003/10/19 03:17:20 coldstore Exp $

package provide httpd::template 1.0

package require httpd::subst
package require httpd::cookie

# Set the file extension for templates

if {![info exists Template(tmlExt)]} {
    set Template(tmlExt) .tml
}
if {![info exists Template(htmlExt)]} {
    switch $tcl_platform(platform) {
	windows { set Template(htmlExt) .htm }
	default { set Template(htmlExt) .html }
    }
}


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

    return [Httpd_ReturnData $sock text/html \
	    [TemplateInstantiate $sock $path {} $suffix {} $Template(templateInterp)]]
}

# Doc_text/html --
#
# This  supports templates.  If enabled, a check is made for the
# corresponding template file.  If it is newer, then it is processed
# and the result is cached in the .html file.
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
#	Returns a page to the client.  May use a corresponding template
#	to generate, and cache, the page.

proc Doc_text/html {path suffix sock} {
    global Template
    upvar #0 Httpd$sock data
    if {$Template(checkTemplates)} {
	# See if the .html cached result is up-to-date
    
	set template [file root $path]$Template(tmlExt)
	if {[file exists $template] && [TemplateCheck $sock $template $path]} {

	    # Do the subst and cache the result in the .html file
	    set html [TemplateInstantiate $sock $template $path $suffix dynamic \
		    $Template(templateInterp)]
	    if {$dynamic} {
		# If the content type was set, use it.  Otherwise, use the default.
		if {[info exists data(contentType)]} {
		    set ctype $data(contentType)
		} else {
		    set ctype "text/html"
		}
		return [Httpd_ReturnData $sock $ctype $html]
	    }
	}
    }
    # Use ReturnFile so remote end knows it can cache the file.
    # This file may have been generated by TemplateInstantiate above.

    return [Httpd_ReturnFile $sock text/html $path]
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
#	None
#
# Side Effects:
#	Generates a page.  Will set up the CGI environment via the ncgi
#	module, and will do environment variable settings.

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
    Cgi_SetEnvInterp $sock $filename $interp

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

    foreach libfile [TemplateGetTemplates $sock $template] {
	if {[file exists $libfile]} {
	    interp eval $interp [list uplevel #0 [list source $libfile]]
	}
    }

    # Process the template itself

    set code [catch {Subst_File $template $interp} html]

    if {$code != 0} {
	# pass errors up - specifically Redirect return code
	global errorCode errorInfo
	return -code $code -errorcode $errorCode -errorinfo$errorInfo
    }

    # Save return cookies, if any
    Cookie_Save $interp $sock

    set dynamic [interp eval $interp {uplevel #0 {set page(dynamic)}}]
    if {!$dynamic} {

	# Cache the result

	catch {file delete -force $htmlfile}
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
	
    foreach libfile [TemplateGetTemplates $sock $template] {
	if {[file exists $libfile] && ([file mtime $libfile] > $mtime)} {
	    return 1
	}
    }
    return [expr {[file mtime $template] > $mtime}]
}


# TemplateGetTemplates --
#	
#	Return a list of unique .tml files that need to be sourced for a template
#
# Arguments:
#	sock		The client connection
#	template	The template file pathname.
#
# Results:
#	A list of .tml file names.
#
# Side Effects:
#	None.

proc TemplateGetTemplates {sock template} {
    global Doc Template
    upvar #0 Httpd$sock data

    # Start at the Doc_AddRoot point

    if {[info exist Doc(root,$data(prefix))]} {
	set root $Doc(root,$data(prefix))

	# always source the .tml in the rootdir
	set tmls [list [file join $Doc(root) $Template(tmlExt)]]
    } else {
	set root $Doc(root,/)
	set tmls {}
    }

    set tmpldirs [file split [file dirname $template]]
    if {[string match ${root}* $template]} {

	# Normal case of pathname under domain prefix

	set path $root
	set extra [lrange $tmpldirs [llength [file split $root]] end]

    } elseif {[set hindex [lsearch -exact $tmpldirs $Doc(homedir)]] >= 0} {
	
	# "public_html" is in the template name, so we have been warped
	# to a user's URL tree.

	set path [eval file join [lrange $tmpldirs 0 $hindex]]
	incr hindex
	set extra [lrange $tmpldirs $hindex end]
    } else {
	# Don't know where we are - just use the one in the current directory

	set path [file dirname $template] 
	set extra {}
    }
    foreach dir [concat [list {}] $extra] {
	set path [file join $path $dir]
	set file [file join $path $Template(tmlExt)]
	# Don't add duplicates to the list.
	if {[lsearch $tmls $file] == -1} {
	    lappend tmls $file
	}
    }

    return $tmls
}
