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
# Brent Welch (c) 1999 Scriptics Corporation
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) doc.tcl 1.20 97/08/05 15:02:32

package provide doc 1.1

# Query or set the physical pathname of the document root
proc Doc_Root {{real {}}} {
    global Doc
    if {[string length $real] > 0} {
	set Doc(root) $real
	Doc_AddRoot / $real
    } else {
	return $Doc(root)
    }
}

# Add a file system to the virtual document hierarchy

proc Doc_AddRoot {virtual directory} {
    Url_PrefixInstall $virtual [list DocDomain $virtual $directory]
}

# Define the index file for a directory

proc Doc_IndexFile {pat} {
    global Doc
    set Doc(indexpat) $pat
}

# Set the suffix for templates
set Doc(tmlSuffix) .tml

# Define a pattern of files names to exclude in DocFallback

proc Doc_ExcludePat {patlist} {
    global Doc
    set Doc(excludePat) $patlist
}
if {![info exists Doc(excludePat)]} {
    set Doc(excludePat) {*.bak *.swp *~}
}

# Allow or disable automatic template checking

proc Doc_CheckTemplates {{how 1}} {
    global Doc
    set Doc(checkTemplates) $how
}
if {![info exists Doc(checkTemplates)]} {
    set Doc(checkTemplates) 0
}

# Choose an alternate interpreter in which to process templates

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

# Define the auto_load library for template support

proc Doc_TemplateLibrary {dir} {
    global Doc auto_path
    set Doc(templateLibrary) $dir
    lappendOnce auto_path $dir
}

# Enable URLS of the form ~user/a/b/c and map those to
# a subdirectory of that users account.

proc Doc_PublicHtml {{homedir public_html}} {
    global Doc
    set Doc(homedir) $homedir
}

# Register a file not found error page.
# This page always gets "subst'ed"

proc Doc_NotFoundPage { virtual } {
    global Doc
    set Doc(page,notfound) [Doc_Virtual {} {} $virtual]
}

# Register a server error page.
# This page always gets "subst'ed"

proc Doc_ErrorPage { virtual } {
    global Doc
    set Doc(page,error) [Doc_Virtual {} {} $virtual]
}

# Define an email address for the webmaster

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
    if {[regexp ^/ $virtual]} {
	set list [lrange [split $virtual /] 1 end]
	return [eval {file join $Doc(root)} $list]
    }
    return {}
}

proc Doc_File {sock curfile npath} {
    return [file join [file dirname $curfile] $npath]
}

# Main handler for Doc domains (i.e. file systems)
# This looks around for a file and, if found, uses DocHandle
# to return the contents.  The call to DocHandle is cached
# by Url_Handle for future accesses to this url.

proc DocDomain {virtual directory sock suffix} {
    global Doc
    upvar #0 Httpd$sock data

    # Make sure the path doesn't sneak out via ..

    if {[catch {Url_PathCheck $suffix} pathlist]} {
	Doc_NotFound $sock
	return
    }

    # Check for personal home pages

    if {[regexp ^~ $pathlist] && [info exists Doc(homedir)]} {
	set user [lindex $pathlist 0]
	if {[catch {glob $user} homedir]} {
	    Doc_NotFound $sock
	    return	;# No such user
	}
	set directory [file join $homedir $Doc(homedir)]
	set pathlist [lrange $pathlist 1 end]
    }

    # Look for .htaccess files along the path

    set cookie [Auth_Check $sock $directory $pathlist]

    # Handle existing files

    set path [eval {file join $directory} $pathlist]
    if {[file exists $path]} {
	Incr Doc(hit,$data(url))
	Url_Handle [list DocHandle $path $suffix $cookie] $sock
	return
    }

    # Try to find an alternate.

    if {![DocFallback $path $suffix $cookie $sock]} {
	# Couldn't find anything.
	# check for cgi script in the middle of the path
	Cgi_Domain $virtual $directory $sock $suffix
    }
}

# DocFallback does "content negotation" if a file isn't found
# look around for files with different suffixes but the same root.

proc DocFallback {path suffix cookie sock} {
    set root [file root $path]
    if {[string match */ $root]} {
	# Input is something like /a/b/.xyz
	return 0
    }
    set ok {}
    set accept [DocAccept $sock]
    foreach choice [glob -nocomplain $root.*] {
	set type [Mtype $choice]
	if {[DocMatch $accept $type] && ![DocExclude $choice]} {
	    lappend ok $choice
	}
    }
    set npath [DocChoose $accept $ok]
    if {[string length $npath] == 0 || [string compare $path $npath] == 0} {
	# not found or still trying one we cannot use
	return 0
    } else {
	# Another hack for templates.  If the .html is not found,
	# and the .tml exists, ask for .html so the template is
	# processed and cached as the .html file.
	global Doc
	if {[string compare $Doc(tmlSuffix) [file extension $npath]] == 0} {
	    # More HACKs
	    if {![Auth_Verify $sock $cookie]} {
		return 1	;# appropriate response already generated
	    }
	    Doc_text/html [file root $npath].html $suffix $sock
	    return 1
	}
	# Redirect so we don't propagate spelling errors like john.osterhoot
	set new [file extension $npath]
	set old [file extension $suffix]
	if {[string length $old] == 0} { 
	    append suffix $new
	} else {
	    regsub $old\$ $suffix $new suffix
	}

	# This next statement only works if the domain prefix is /
	Httpd_RedirectSelf /$suffix $sock

	return 1
    }
}

# These procedures compare a document type with the Accept values.

proc DocAccept {sock} {
    upvar #0 Httpd$sock data
    set accept */*
    catch {set accept $data(mime,accept)}
    return $accept
}
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

# This is used to filter out files like "foo.bak"  and foo~
# from the DocFallback failover code

proc DocExclude {name} {
    global Doc
    foreach pat $Doc(excludePat) {
	if {[string match $pat $name]} {
	    return 1
	}
    }
    return 0
}

# Choose based first on the order of things in the Accept type list,
# then on the newest file that matches a given accept pattern.

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

# Handle a document URL.  Dispatch to the mime type handler, if defined.

proc DocHandle {path suffix cookie sock} {
    upvar #0 Httpd$sock data
    if {![Auth_Verify $sock $cookie]} {
	return	;# appropriate response already generated
    }
    if {[file isdirectory $path]} {
	if {[string length $data(url)] && ![regexp /$ $data(url)]} {
	    # Insist on the trailing slash
	    Httpd_RedirectDir $sock
	    return
	}
	DocDirectory $path $suffix $cookie $sock
    } elseif {[file readable $path]} {
	set cmd Doc_[Mtype $path]
	if {![iscommand $cmd]} {
	    Httpd_ReturnFile $sock [Mtype $path] $path
	} else {
	    $cmd $path $suffix $sock
	}
    } else {
	# Probably not found, but an old UrlCache entry might have
	# brought us here.  We try content negotiation in case
	# the file's name changed.

	Url_UnCache $sock
	if {![DocFallback $path $suffix $cookie $sock]} {
	    Doc_NotFound $sock
	}
    }
}

# For directories, return the newest file that matches
# the index file pattern.

proc DocDirectory {path suffix cookie sock} {
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
	if {[string compare $Doc(tmlSuffix) [file extension $newest]] == 0} {
	    foreach try [list [file root $newest].html [file root $newest].htm] {
		if {[file exists $try]} {
		    # Ask for .html so it gets generated from the template
		    set newest $try
		    break
		}
	    }
	}
	# Don't cache translation this to avoid latching onto the wrong file
	return [DocHandle $newest $suffix $cookie $sock]
    }

    Httpd_ReturnData $sock text/html [DirList $path $data(url)]
}

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

proc Doc_NotFound { sock } {
    global Doc Referer
    upvar #0 Httpd$sock data
    if {[info exists data(url)]} {
	Url_UnCache $sock
	Incr Doc(notfound,$data(url))
	set Doc(url,notfound) $data(url)	;# For subst
	if {[info exists data(mime,referer)]} {
	    lappendOnce Referer($data(url)) $data(mime,referer)
	}
    } else {
	set Doc(url,notfound) {}
    }
    DocSubstSystemFile $sock notfound 404 [protect_text $Doc(url,notfound)]
}
proc Doc_Error { sock ei } {
    global Doc
    upvar #0 Httpd$sock data
    if {[info exists data(url)]} {
	Url_UnCache $sock
	Incr Doc(error,$data(url))
	set Doc(errorUrl) $data(url)
    } else {
	set Doc(errorUrl) ""
    }
    set Doc(errorInfo) $ei	;# For subst
    DocSubstSystemFile $sock error 500 [protect_text $ei]
}

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

# this is called by DocHandle to process .map files

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

# Tcl-subst a template that mixes HTML and Tcl.
# This subst is just done in the context of the specified
# interpreter with not much other support.
# See x-tcl-template for something more sophisticated

proc Doc_application/x-tcl-subst {path suffix sock {interp {}}} {
    upvar #0 Httpd$sock data

    Cgi_SetEnv	$sock $path pass
    interp eval $interp [list uplevel #0 [list array set env [array get pass]]]
    Doc_Subst $sock $path $interp
}

# Tcl-subst a template that mixes HTML and Tcl.

proc Doc_application/x-tcl-template {path suffix sock} {
    upvar #0 Httpd$sock data
    global Doc

    # This is always dynamic (ReturnData has no modification date)
    # so the result is not cached at the remote end.

    return [Httpd_ReturnData $sock text/html \
	    [DocTemplate $sock $path {} $suffix {} $Doc(templateInterp)]]
}

# This  supports templates.  If enabled, a check is made for the
# corresponding template file.  If it is newer, then it is processed
# and the result is cached in the .html file.

proc Doc_text/html {path suffix sock} {
    global Doc
    upvar #0 Httpd$sock data
    if {$Doc(checkTemplates)} {
	# See if the .html cached result is up-to-date
    
	set template [file root $path]$Doc(tmlSuffix)
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
    return [Httpd_ReturnFile $sock text/html $path]
}

# Like tcl-subst, but a basic authentication cookie is used for session state

proc Doc_application/x-tcl-auth {path suffix sock} {
    upvar #0 Httpd$sock data

    if {![info exists data(session)]} {
	Httpd_RequestAuth $sock Basic "Random Password"
	return
    }
    set interp [Session_Authorized $data(session)]

    global env
    # Need to make everything look like a GET so the Cgi parser
    # doesn't read post data from stdin.  We've already read it.
    set data(proto) GET
    Cgi_SetEnv	$sock $path pass
    interp eval $interp [list uplevel #0 [list array set env [array get pass]]]

    Doc_Subst $sock $path $interp
}

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

    # Duplicate this in the "cgienv" array.

    interp eval $interp [list uplevel #0 \
	{catch {unset cgienv}}]
    interp eval $interp [list uplevel #0 \
	[list array set cgienv [array get pass]]]

    # Check query data
    # steve: 5/8/98: Add multipart document upload handling
    # If there is out-standing (i.e., unread) post data, then
    # calling Url_DecodeQuery will automatcally read it
    # and append to data(query)

    if {[Httpd_PostDataSize $sock] > 0 && ![info exists data(query)]} {
	set data(query) {}
    }
    if {[info exist data(query)]} {
	set queryType application/x-www-urlencoded
	set qualifiers {}
	catch {
	    foreach {major minor qualifiers} [Url_DecodeMIMEField $data(mime,content-type)] break
	    set queryType $major/$minor
	}
	set querylist [Url_DecodeQuery $data(query) -type $queryType -qualifiers $qualifiers]

	interp eval $interp [list uplevel #0 [list set page(realquery) $data(query)]]
	interp eval $interp [list uplevel #0 [list set page(querytype) $queryType]]
	interp eval $interp [list uplevel #0 [list set page(query) $querylist]]
    }

    # Source the .tml files from the root downward.

    set path $Doc(root)
    foreach dir [concat [list {}] $dirs] {
	set path [file join $path $dir]
	set libfile [file join $path $Doc(tmlSuffix)]
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

proc Doc_IsLinkToSelf {url} {
    global page
    return [expr {[string compare $url $page(url)] == 0}]
}

# Trigger a page redirect

proc Doc_Redirect {newurl} {
    return -code error \
	    -errorcode  [list HTTPD_REDIRECT $newurl] \
	    "Redirect to $newurl"
}

proc Doc_RedirectSelf {newurl} {
    Doc_Redirect [Httpd_SelfUrl $newurl]
}

# Check modify times on all templates that affect a page

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
	set libfile [file join $path $Doc(tmlSuffix)]
	if {[file exists $libfile] && ([file mtime $libfile] > $mtime)} {
	    return 1
	}
    }
    return [expr {[file mtime $template] > $mtime}]
}


# Subst a file in an interpreter context

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

# Subst a file and return the result to the HTTP client.
# Note that ReturnData has no Modification-Date so the result is not cached.

proc Doc_Subst {sock path {interp {}}} {
    Httpd_ReturnData $sock text/html [DocSubst $path $interp]
}
