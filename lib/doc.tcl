# doc.tcl
#
# File system based URL support.
# This calls out to the Auth module to check for access files.
# Once a file is found, it checks for content-type handlers defined
# by Tcl procs of the form Doc_$contentType.  If those are present
# then they are responsible for processing the file and returning it.
# Otherwise the file is returned by DocHandle.
#
# If a file is not found then a limited form of content negotiation is
# done based on the browser's Accept header.  For example, this makes
# it easy to transition between foo.shtml and foo.html.  Just rename
# the file and content negotiation will find it from old links.
#
# There are also handlers for server errors and doc-not-found cases.
# Template processing is supported by Doc_Subst.
#
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: doc.tcl,v 1.39 2000/09/20 00:25:44 welch Exp $

package provide httpd::doc 1.1

package require uri

# Doc_Root --
#
# Query or set the physical pathname of the document root
#
# Arguments:
#	real 	Optional.  The name of the file system directory
#		containing the root of the URL tree.  If this is empty,
#		then the current document root is returned instead.
#
# Results:
#	The name of the directory of the document root.
#
# Side Effects:
#	Sets the document root.

proc Doc_Root {{real {}}} {
    global Doc
    if {[string length $real] > 0} {
	set Doc(root) $real
	Doc_AddRoot / $real
    } else {
	return $Doc(root)
    }
}

# Doc_AddRoot
#	Add a file system to the virtual document hierarchy
#
# Arguments
#	virtual		The prefix of the URL
#	directory	The directory that corresponds to $virtual
#	inThread	True if document handlers should run in a thread
#			The default is true to handle long-running templates
#
# Arguments:
#	virtual		The URL prefix of the document tree to add.
#	directory	The file system directory containing the doc tree.
#	inThread 1	If true, the domain is registered to run in a thread.
#			(The server may have threading turned off, but
#			you can still ask for it without error.)
#
# Results:
#	None
#
# Side Effects:
#	Sets up a document URL domain and the document-based access hook.

proc Doc_AddRoot {virtual directory {inThread 1}} {
    global Doc
    set Doc(root,$virtual) $directory
    Url_PrefixInstall $virtual [list DocDomain $virtual $directory] $inThread
    Url_AccessInstall DocAccessHook
}

# Doc_IndexFile --
#
#	Define the index file for a directory
#
# Arguments:
#	pat	A glob pattern for index files in a directory.
#
# Results:
#	None
#
# Side Effects:
#	Sets the index file glob pattern.

proc Doc_IndexFile {pat} {
    global Doc
    set Doc(indexpat) $pat
}

# Doc_ExcludePat --
#
# Define a pattern of files names to exclude in DocFallback
#
# Arguments:
#	patlist	A glob pattern of files to avoid when playing
#		games in DocFallBack to find an alternative file.
#
# Results:
#	None
#
# Side Effects:
#	Sets the exclude pattern.

proc Doc_ExcludePat {patlist} {
    global Doc
    set Doc(excludePat) $patlist
}
if {![info exists Doc(excludePat)]} {
    set Doc(excludePat) {*.bak *.swp *~}
}

# Set the file extension for templates

if {![info exists Doc(tmlExt)]} {
    set Doc(tmlExt) .tml
}
if {![info exists Doc(htmlExt)]} {
    switch $tcl_platform(platform) {
	windows { set Doc(htmlExt) .htm }
	default { set Doc(htmlExt) .html }
    }
}

# Doc_CheckTemplates --
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

proc Doc_CheckTemplates {{how 1}} {
    global Doc
    set Doc(checkTemplates) $how
}
if {![info exists Doc(checkTemplates)]} {
    set Doc(checkTemplates) 0
}

# Doc_TemplateInterp --
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

proc Doc_TemplateInterp {interp} {
    global Doc
    if {[string length $interp] && ![interp exists $interp]} {
	interp create $interp
    }
    set Doc(templateInterp) $interp
}
if {![info exists Doc(templateInterp)]} {
    set Doc(templateInterp) {}
}

# Doc_TemplateLibrary --
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

proc Doc_TemplateLibrary {dir} {
    global Doc auto_path
    set Doc(templateLibrary) $dir
    if {$Doc(templateInterp) != {}} {
	interp eval $Doc(templateInterp) [list lappendOnce ::auto_path $dir]
    } else {
	lappendOnce auto_path $dir
    }
}

# Doc_PublicHtml --
#
# Enable URLS of the form ~user/a/b/c and map those to
# a subdirectory of that users account.
#
# Arguments:
#	homedir The directory under a user's home that is their
#		personal URL root.  Defaults to public_html.
#		If this is empty, then user home directories
#		are disabled.
#
# Results:
#	None
#
# Side Effects:
#	Sets the per-user public_html directory name.

proc Doc_PublicHtml {{homedir public_html}} {
    global Doc
    if {[string length $homedir] == 0} {
	catch {unset Doc(homedir)}
    } else {
	set Doc(homedir) [string trim $homedir /]
    }
}

# Doc_NotFoundPage --
#
# Register a file not found error page.
# This page always gets "subst'ed, but without the fancy
# context of the ".tml" pages.
#
# Arguments:
#	virtual	The URL of the not-found page, e.g., /notfound.html
#
# Results:
#	None
#
# Side Effects:
#	Sets the not-found page.

proc Doc_NotFoundPage { virtual } {
    global Doc
    set Doc(page,notfound) [Doc_Virtual {} {} $virtual]
}

# Doc_ErrorPage --
#
# Register a server error page.
# This page always gets "subst'ed"
#
# Arguments:
#	virtual	The URL of the error page, e.g., /error.html
#
# Results:
#	None
#
# Side Effects:
#	Sets the error page.

proc Doc_ErrorPage { virtual } {
    global Doc
    set Doc(page,error) [Doc_Virtual {} {} $virtual]
}

# Doc_Webmaster --
#
# Define an email address for the webmaster
#
# Arguments:
#	email 	The email of the webmaster.  If empty, the
#		current value is returned, which is handy in
#		web pages.
#
# Results:
#	Returns the webmaster email.
#
# Side Effects:
#	Sets the webmaster email.

proc Doc_Webmaster {{email {}}} {
    global Doc
    if {[string length $email] == 0} {
	if {![info exists Doc(webmaster)]} {
	    set Doc(webmaster) webmaster
	}
	return $Doc(webmaster)
    } else {
	set Doc(webmaster) $email
    }
}

# Doc_Virtual - return a real pathname corresponding to a 
# "virtual" path in an include
#
# Arguments:
#	sock	The client connection.
#	curfile	The pathname of the file that contains the
#		"virtual" URL spec.  This is used to resolve
#		relative URLs.
#	virtual	The URL we need the file name of.
#
# Results:
#	The file name corresponding to the URL.
#	If "" is returned, then the URL is invalid.
#
# Side Effects:
#	None

proc Doc_Virtual {sock curfile virtual} {
    global Doc
    if {[regexp ^~ $virtual]} {
	# This is UNIX-specific, so we don't need file joins
	if {![info exists Doc(homedir)]} {
	    return {}	;# Not allowed
	}
	set list [split $virtual /]
	set user [lindex $list 0]
	if {[catch {glob $user} homedir]} {
	    return {}	;# No such user
	}
	return $homedir/$Doc(homedir)/[join [lrange $list 1 end] /]
    }

    # Try to hook up the pathname under the appropriate document root

    if {[regexp ^/ $virtual]} {
	Url_PrefixMatch $virtual prefix suffix
	if {[info exist Doc(root,$prefix)]} {
	    return [file join $Doc(root,$prefix) [string trimleft $suffix /]]
	} else {
	    # Not a document domain, so there cannot be a file behind this url.

	    return {}
	}
    }

    # Non-absolute URL

    return [file join [file dirname $curfile] $virtual]
}

# Doc_File --
#
#	DEPRECATED.  This is a trivial layer over file join.
#
# Arguments:
#	sock	The client connection.
#	curfile	The current file containing a file= specification.
#	npath	The file name, which might be relative to curfile.
#
# Results:
#	A file pathname.
#
# Side Effects:
#	None

proc Doc_File {sock curfile npath} {
    return [file join [file dirname $curfile] $npath]
}

# DocAccessHook
#
#	Access handle for Doc domains.
#	This looks for special files in the file system that
#	determine access control.  This is registered via
#	Url_AccessInstall
#
# Arguments:
#	sock	Client connection
#	url	The full URL. We realy need the prefix/suffix, which
#		is stored for us in the connection state
#
# Results:
#	"denied", in which case an authorization challenge or
#	not found error has been returned.  Otherwise "skip"
#	which means other access checkers could be run, but
# 	most likely access will be granted.

proc DocAccessHook {sock url} {
    global Doc
    upvar #0 Httpd$sock data

    # Make sure the path doesn't sneak out via ..
    # This turns the URL suffix into a list of pathname components

    if {[catch {Url_PathCheck $data(suffix)} data(pathlist)]} {
	Doc_NotFound $sock
	return denied
    }

    # Figure out the directory corresponding to the domain, taking
    # into account other document roots.

    if {[info exist Doc(root,$data(prefix))]} {
	set directory $Doc(root,$data(prefix))
    } else {
	set directory [file join $Doc(root,/) [string trimleft $data(prefix) /]]
    }

    # Look for .htaccess and .tclaccess files along the path
    # If you wanted to have a time-limited cache of these
    # cookies you could save the cost of probing the file system
    # for these files on each URL.

    set cookie [Auth_Check $sock $directory $data(pathlist)]

    # Finally, check access

    if {![Auth_Verify $sock $cookie]} {
	return denied
    } else {
	return skip
    }
}

# DocDomain --
#
# Main handler for Doc domains (i.e. file systems)
# This looks around for a file and, if found, uses DocHandle
# to return the contents.
#
# Arguments:
#	prefix		The URL prefix of the domain.
#	directory	The directory containing teh domain.
#	sock		The socket connection.
#	suffix		The URL after the prefix.
#
# Results:
#	None
#
# Side Effects:
#	Dispatch to the document handler that is in charge
#	of generating an HTTP response.

proc DocDomain {prefix directory sock suffix} {
    global Doc
    upvar #0 Httpd$sock data

    # The pathlist has been checked and URL decoded by
    # DocAccess, so we ignore the suffix and recompute it.

    set pathlist $data(pathlist)
    set suffix [join $pathlist /]

    # Check for personal home pages

    if {[regexp ^~ $pathlist] && [info exists Doc(homedir)]} {
	set user [lindex $pathlist 0]
	if {[catch {glob $user} homedir]} {
	    Doc_NotFound $sock
	    return	;# No such user
	}
	set directory [file join $homedir $Doc(homedir)]
	set pathlist [lrange $pathlist 1 end]
	set suffix [join $pathlist /]
    }

    # Handle existing files

    # The file join here is subject to attacks that create absolute
    # pathnames outside the URL tree.  We trim left the / and ~
    # to prevent those attacks.

    set path [file join $directory [string trimleft $suffix /~]]
    if {[file exists $path]} {
	CountName $data(url) hit
	DocHandle $prefix $path $suffix $sock
	return
    }

    # Try to find an alternate.

    if {![DocFallback $prefix $path $suffix $sock]} {
	# Couldn't find anything.
	# check for cgi script in the middle of the path
	Cgi_Domain $prefix $directory $sock $suffix
    }
}

# DocFallback does "content negotation" if a file isn't found
# look around for files with different suffixes but the same root.
#
# NOTE: This feature is probably more trouble than it is worth.
# It was originally used to be able to choose between different
# iamge types (e.g., .gif and .jpg), but is now also used to
# find templates (.tml files) that correspond to .html files.
#
# Arguments:
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

proc DocFallback {virtual path suffix sock} {
    set root [file root $path]
    if {[string match */ $root]} {
	# Input is something like /a/b/.xyz
	return 0
    }

    # Here we look for files indicated by any Accept headers.
    # Most browsers say */*, but they may provide some ordering info, too.

    set ok {}
    foreach choice [glob -nocomplain $root.*] {
	
	# Filter on the exclude patterns, and make sure that we
	# don't let "foo.html.old" match for "foo.html"

	if {[string compare [file root $choice] $root] == 0 &&
		![DocExclude $choice]} {
	    lappend ok $choice
	}
    }

    # Now we pick the best file from the ones that matched.

    set npath [DocChoose [DocAccept $sock] $ok]
    if {[string length $npath] == 0 || [string compare $path $npath] == 0} {

	# not found or still trying one we cannot use

	return 0
    } else {

	# Another hack for templates.  If the .html is not found,
	# and the .tml exists, ask for .html so the template is
	# processed and cached as the .html file.

	global Doc
	if {[string compare $Doc(tmlExt) [file extension $npath]] == 0} {
	    Doc_text/html [file root $npath]$Doc(htmlExt) $suffix $sock
	    return 1
	}

	# Redirect so we don't mask spelling errors like john.osterhoot

	set new [file extension $npath]
	set old [file extension $suffix]
	if {[string length $old] == 0} { 
	    append suffix $new
	} else {
	    # Watch out for specials in $old, like .html)

	    regsub -all {[][$^|().*+?\\]} $old {\\&} old
	    regsub $old\$ $suffix $new suffix
	}

	Httpd_RedirectSelf $virtual/[string trimleft $suffix /~] $sock

	return 1
    }
}

# DocAccept --
#
#	This returns the Accept specification from the HTTP headers.
#	These are a list of MIME types that the browser favors.
#
# Arguments:
#	sock	The socket connection
#
# Results:
#	The Accept header, or a default.
#
# Side Effects:
#	None

proc DocAccept {sock} {
    upvar #0 Httpd$sock data
    if {![info exist data(mime,accept)]} {
	return */*
    } else {
	return $data(mime,accept)
    }
}
# DocMatch --
#
# 	This compares a document type with the Accept values.
#
# Arguments:
#	accept	The results of DocAccept
#	type	A MIME Content-Type.
#
# Results:
#	1	If the content-type matches the accept spec, 0 otherwise.
#
# Side Effects:
#	None

proc DocMatch {accept type} {
    foreach t [split $accept ,] {
	regsub {;.*} $t {} t	;# Nuke quality parameters
	set t [string trim [string tolower $t]]
	if {[string match $t $type]} {
	    return 1
	}
    }
    return 0
}

# DocExclude --
#
# This is used to filter out files like "foo.bak"  and foo~
# from the DocFallback failover code
#
# Arguments:
#	name	The filename to filter.
#
# Results:
#	1	If the file should be excluded, 0 otherwise.
#
# Side Effects:
#	None

proc DocExclude {name} {
    global Doc
    foreach pat $Doc(excludePat) {
	if {[string match $pat $name]} {
	    return 1
	}
    }
    return 0
}

# DocChoose --
#
# Choose based first on the order of things in the Accept type list,
# then on the newest file that matches a given accept pattern.
#
# Arguments:
#	accept	The results of DocAccept
#	choices	The list of matching file names.
#
# Results:
#	The chosen file name.
#
# Side Effects:
#	None

proc DocChoose {accept choices} {
    foreach t [split $accept ,] {
	regsub {;.*} $t {} t	;# Nuke quality parameters
	set t [string trim [string tolower $t]]
	set hits {}
	foreach f $choices {
	    set type [Mtype $f]
	    if {[string match $t $type]} {
		lappend hits $f
	    }
	}
	set result [DocLatest $hits]
	if {[string length $result]} {
	    return $result
	}
    }
    return {}
}

# DocHandle --
#
# Handle a document URL.  Dispatch to the mime type handler, if defined.
#
# Arguments:
#	prefix	The URL prefix of the domain.
#	path	The file system pathname of the file.
#	suffix	The URL suffix.
#	sock	The socket connection.
#
# Results:
#	None
#
# Side Effects:
#	Dispatch to the correct document handler.

proc DocHandle {prefix path suffix sock} {
    upvar #0 Httpd$sock data
    if {[file isdirectory $path]} {
	if {[string length $data(url)] && ![regexp /$ $data(url)]} {

	    # Insist on the trailing slash

	    Httpd_RedirectDir $sock
	    return
	}
	DocDirectory $prefix $path $suffix $sock
    } elseif {[file readable $path]} {
	
	# Look for Tcl procedures whos name match the MIME Content-Type

	set cmd Doc_[Mtype $path]
	if {![iscommand $cmd]} {
	    Httpd_ReturnFile $sock [Mtype $path] $path
	} else {
	    $cmd $path $suffix $sock
	}
    } else {
	# Either not found, or we can find an alternate (e.g. a template).

	if {![DocFallback $prefix $path $suffix $sock]} {
	    Doc_NotFound $sock
	}
    }
}

# DocDirectory --
#
#	Handle a directory.  Look for the index file, falling back to
#	the Directory Listing module, if necessary.
#
# Arguments:
#	prefix	The URL domain prefix.
#	path	The file system pathname of the directory.
#	suffix	The URL suffix.
#	sock	The socket connection.
#
# Results:
#	None
#
# Side Effects:
#	Dispatches to the appropriate page handler.

proc DocDirectory {prefix path suffix sock} {
    upvar #0 Httpd$sock data
    global Doc tcl_platform

    # Special case because glob doesn't work in wrapped files
    # Just set indexpat to "index.tml" or "index.html"

    set npath [file join $path $Doc(indexpat)]
    if {[info exist tcl_platform(isWrapped)] && $tcl_platform(isWrapped)} {
	set newest $npath
    } else {
	set newest [DocLatest [glob -nocomplain $npath]]
    }
    if {[string length $newest]} {

	# Template hack.  Ask for the corresponding .html file in
	# case that file should be cached when running the template.
	# If we ask for the .tml directly then its result is never cached.

	if {[string compare $Doc(tmlExt) [file extension $newest]] == 0} {
	    set newest [file root $newest]$Doc(htmlExt)
	}
	return [DocHandle $prefix $newest $suffix $sock]
    }

    Httpd_ReturnData $sock text/html [DirList $path $data(url)]
}

# DocLatest --
#
#	Return the newest file from the list.
#
# Arguments:
#	files	A list of filenames.
#
# Results:
#	None
#
# Side Effects:
#	The name of the newest file.

proc DocLatest {files} {
    set newest {}
    foreach file $files {
	if {[file readable $file]} {
	    set m [file mtime $file]
	    if {![info exist mtime] || ($m > $mtime)} {
		set mtime $m
		set newest $file
	    }
	}
    }
    return $newest
}

# Doc_NotFound --
#
#	Called when a page is missing.  This looks for a handler page
#	and sets up a small amount of context for it.
#
# Arguments:
#	sock	The socket connection.
#
# Results:
#	None
#
# Side Effects:
#	Returns a page.

proc Doc_NotFound { sock } {
    global Doc Referer
    upvar #0 Httpd$sock data
    CountName $data(url) notfound
    set Doc(url,notfound) $data(url)	;# For subst
    if {[info exists data(mime,referer)]} {

	# Record the referring URL so we can track down
	# bad links

	lappendOnce Referer($data(url)) $data(mime,referer)
    }
    DocSubstSystemFile $sock notfound 404 [protect_text $Doc(url,notfound)]
}

# Doc_Error --
#
#	Called when an error has occurred processing the page.
#
# Arguments:
#	sock	The socket connection.
#	ei	errorInfo
#
# Results:
#	None
#
# Side Effects:
#	Returns a page.

proc Doc_Error { sock ei } {
    global Doc
    upvar #0 Httpd$sock data
    set Doc(errorUrl) $data(url)
    set Doc(errorInfo) $ei	;# For subst
    CountName $Doc(errorUrl) error
    DocSubstSystemFile $sock error 500 [protect_text $ei]
}

# DocSubstSystemFile --
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

proc DocSubstSystemFile {sock key code {extra {}} {interp {}}} {
    global Doc env
    if {![info exists Doc(page,$key)]} {
	set path [Doc_Virtual {} {} /$key.html]
	if {[file exists $path]} {
	    set Doc(page,$key) $path
	}
    }
    if {![info exists Doc(page,$key)] || 
	    [catch {Httpd_ReturnData $sock text/html \
			[DocSubst $Doc(page,$key) $interp] $code} err]} {
	if {[info exists err]} {
	    Log $sock DocSubstSystemFile $err
	}
	Httpd_Error $sock $code $extra
    }
}

# Doc_application/x-imagemap --
#
# this is called by DocHandle to process .map files
#
# Arguments:
#	path	The file name of the .map file.
#	suffix	The URL suffix
#	sock	The socket connection.
#
# Results:
#	None
#
# Side Effects:
#	Redirect to the URL indicated by the map.

proc Doc_application/x-imagemap {path suffix sock} {
    upvar #0 Httpd$sock data
    if {![info exists data(query)]} {
	Httpd_ReturnData $sock text/plain "[parray Httpd$sock]"
	return
    }
    set url [Map_Lookup $path?$data(query)]
    Count maphits
    Httpd_Redirect $url $sock
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
#	Sets the env array in interp and calls Doc_Subst.

proc Doc_application/x-tcl-subst {path suffix sock {interp {}}} {
    upvar #0 Httpd$sock data

    Cgi_SetEnv	$sock $path pass
    interp eval $interp [list uplevel #0 [list array set env [array get pass]]]
    Doc_Subst $sock $path $interp
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
    global Doc

    # This is always dynamic (ReturnData has no modification date)
    # so the result is not cached at the remote end, nor is a local
    # .html file cached.

    return [Httpd_ReturnData $sock text/html \
	    [DocTemplate $sock $path {} $suffix {} $Doc(templateInterp)]]
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
    global Doc
    upvar #0 Httpd$sock data
    if {$Doc(checkTemplates)} {
	# See if the .html cached result is up-to-date
    
	set template [file root $path]$Doc(tmlExt)
	if {[file exists $template] && [DocCheckTemplate $template $path]} {

	    # Do the subst and cache the result in the .html file

	    set html [DocTemplate $sock $template $path $suffix dynamic \
		    $Doc(templateInterp)]
	    if {$dynamic} {
		return [Httpd_ReturnData $sock text/html $html]
	    }
	}
    }
    # Use ReturnFile so remote end knows it can cache the file.
    # This file may have been generated by DocTemplate above.

    return [Httpd_ReturnFile $sock text/html $path]
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
    Cgi_SetEnv	$sock $path pass
    interp eval $interp [list uplevel #0 [list array set env [array get pass]]]

    Doc_Subst $sock $path $interp
}

# DocTemplate --
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

proc DocTemplate {sock template htmlfile suffix dynamicVar {interp {}}} {
    upvar #0 Httpd$sock data
    upvar $dynamicVar dynamic
    global Doc

    # Look for .tml library files down the hierarchy.

    set rlen [llength [file split $Doc(root)]]
    set dirs [lrange [file split [file dirname $template]] $rlen end]

    # Populate the global "page" array with state about this page

    set root ""
    foreach d $dirs {
	append root ../
    }
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
	filename	$filename	\
	root		$root		\
	dynamic		$dynamic	\
	set-cookie	{}		\
    ]]]

    # Populate the global "env" array similarly to the CGI environment

    Cgi_SetEnv $sock $filename pass
    interp eval $interp [list uplevel #0 \
	[list array set env [array get pass]]]

    if {0} {
	# Duplicate this in the "cgienv" array.

	interp eval $interp [list uplevel #0 \
	    {catch {unset cgienv}}]
	interp eval $interp [list uplevel #0 \
	    [list array set cgienv [array get pass]]]
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

    set path $Doc(root)
    foreach dir [concat [list {}] $dirs] {
	set path [file join $path $dir]
	set libfile [file join $path $Doc(tmlExt)]
	if {[file exists $libfile]} {
	    interp eval $interp [list uplevel #0 [list source $libfile]]
	}
    }

    # Process the template itself

    set code [catch {DocSubst $template $interp} html]

    # Save return cookies, if any

    if {![catch {
	interp eval $interp {uplevel #0 {set page(set-cookie)}}
    } cookie]} {
	foreach c $cookie {
	    Httpd_SetCookie $sock $c
	}
	interp eval $interp {uplevel #0 {unset page(set-cookie)}}
    }

    if {$code != 0} {
	global errorCode errorInfo
	return -code $code -errorcode $errorCode -errorinfo $errorInfo
    }

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

# Doc_Dynamic
#	Supress generation of HTML cache
#
# Arguments:
#
# Results:
#	None
#
# Side Effects:
#	Sets the dynamic bit so the page is not cached.

proc Doc_Dynamic {} {
    global page
    set page(dynamic) 1
    return "<!-- DynamicOnly -->\n"
}

# Doc_Cookie
#
#	Return a *list* of cookie values, if present, else ""
#	It is possible for multiple cookies with the same key
#	to be present, so we return a list.
#
# Arguments:
#	cookie	The name of the cookie (the key)


proc Doc_Cookie {cookie} {
    global env
    set result ""
    if {[info exist env(HTTP_COOKIE)]} {
	foreach pair [split $env(HTTP_COOKIE) \;] {
	    lassign [split [string trim $pair] =] key value
	    if {[string compare $cookie $key] == 0} {
		lappend result $value
	    }
	}
    }
    return $result
}

# Doc_SetCookie
#
#	Set a return cookie
#
# Arguments:
#	args	Name value pairs, where the names are:
#		-name	Cookie name
#		-value	Cookie value
#		-path	Path restriction
#		-domain	domain restriction
#		-expires	Time restriction

proc Doc_SetCookie {args} {
    global page
    array set opt $args
    set line "$opt(-name)=$opt(-value) ;"
    foreach extra {path domain} {
	if {[info exist opt(-$extra)]} {
	    append line " $extra=$opt(-$extra) ;"
	}
    }
    if {[info exist opt(-expires)]} {
	switch -glob -- $opt(-expires) {
	    *GMT {
		set expires $opt(-expires)
	    }
	    default {
		set expires [clock format [clock scan $opt(-expires)] \
			-format "%A, %d-%b-%Y %H:%M:%S GMT" -gmt 1]
	    }
	}
	append line " expires=$expires ;"
    }
    if {[info exist opt(-secure)]} {
	append line " secure "
    }
    lappend page(set-cookie) $line
}

# Doc_IsLinkToSelf
#	Compare the link to the URL of the current page.
#	If they seem to be the same thing, return 1
#
# Arguments:
#	url	The URL to compare with.
#
# Results:
#	1 if the input URL seems to be equivalent to the page's URL.
#
# Side Effects:
#	None

proc Doc_IsLinkToSelf {url} {
    global page
    return [expr {[string compare $url $page(url)] == 0}]
}

# Doc_Redirect --
#
# Trigger a page redirect
#
# Arguments:
#	newurl	The new URL
#
# Results:
#	None
#
# Side Effects:
#	Raises a special error that is caught by Url_Unwind

proc Doc_Redirect {newurl} {
    return -code error \
	    -errorcode  [list HTTPD_REDIRECT $newurl] \
	    "Redirect to $newurl"
}

# Doc_RedirectSelf --
#
#	Like Doc_Redirect, but to a URL that is relative to this server.
#
# Arguments:
#	newurl	Server-relative URL
#
# Results:
#	None
#
# Side Effects:
#	See Doc_Redirect

proc Doc_RedirectSelf {newurl} {
    set thispage [ncgi::urlStub]
    set thisurl [Httpd_SelfUrl $thispage]
    set newurl [uri::resolve $thisurl $newurl]
    Doc_Redirect $newurl
}

# DocCheckTemplate --
#
# Check modify times on all templates that affect a page
#
# Arguments:
#	template	The file pathname of the template.
#	htmlfile	The file pathname of the cached .html file.
#
# Results:
#	1 if the template or any dependent .tml file are newer than
#	the cached .html file.
#
# Side Effects:
#	None

proc DocCheckTemplate {template htmlfile} {
    global Doc

    if {[file exists $htmlfile]} {
	set mtime [file mtime $htmlfile]
    } else {
	return 1
    }

    # Look for .tml library files down the hierarchy.

    set rlen [llength [file split $Doc(root)]]
    set dirs [lrange [file split [file dirname $template]] $rlen end]

    set path $Doc(root)
    foreach dir [concat [list {}] $dirs] {
	set path [file join $path $dir]
	set libfile [file join $path $Doc(tmlExt)]
	if {[file exists $libfile] && ([file mtime $libfile] > $mtime)} {
	    return 1
	}
    }
    return [expr {[file mtime $template] > $mtime}]
}


# DocSubst --
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

proc DocSubst {path {interp {}}} {

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

# Doc_Subst --
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

proc Doc_Subst {sock path {interp {}}} {
    Httpd_ReturnData $sock text/html [DocSubst $path $interp]
}
