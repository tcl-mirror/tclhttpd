# deubg.tcl --
#
#	Application-direct URLs to help debugg the server.
# 	Tcl procedures of the form debug/hello implement URLS
#	of the form /debug/hello
#
# Brent Welch (c) Copyright 1998 Scriptics Corporation.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
package provide debug 1.0

proc Debug_Url {dir} {
    Direct_Url $dir Debug
}

proc Debug/source {source} {
    global Httpd Doc
    set source [file tail $source]
    set dirlist $Httpd(library)
    if {[info exists Doc(templateLibrary)]} {
	lappend dirlist $Doc(templateLibrary)
    }
    foreach dir $dirlist {
	set file [file join $dir $source]
	if [file exists $file] {
	    break
	}
    }
    set error [catch {uplevel #0 [list source $file]} result]
    set html "<title>Source $source</title>\n"
    if {$error} {
	global errorInfo
	append html "<H1>Error in $source</H1>\n"
	append html "<pre>$result<p>$errorInfo</pre>"
    } else {
	append html "<H1>Reloaded $source</H1>\n"
	append html "<pre>$result</pre>"
    }
    return $html
}

# steve: 24/11/97: reload a package
 
proc Debug/package name {
    if {[catch {
	package forget $name
	catch {namespace delete $name}
	package require $name
    } result]} {
	set html "<title>Error</title>
<H1>Error Reloading Package $name</H1>

Unable to reload package \"$name\" due to:
<PRE>
$result
</PRE>
"
    } else {
	set html "<title>Package reloaded</title>
<H1>Reloaded Package $name</H1>
 
Version $result of package \"$name\" has been (re)loaded.
"
    }
 
    return $html
}
 
proc Debug/pvalue {aname} {
    set html "<title>$aname</title>\n"
    append html [DebugValue $aname]
    return $html
}
proc DebugValue {aname} {
    upvar #0 $aname var
    append html "<p><b><font size=+=>$aname</font></b><br>\n"
    if {[array exists var]} {
	global $aname
	append html "<pre>[parray $aname]</pre>"
    } elseif {[info exists var]} {
	append html "<pre>[list set $aname $var]</pre>"
    } else {
	append html "<ul>"
	foreach n [uplevel #0 [list info vars $aname]] {
	    append html [DebugValue $n]
	}
	append html "</ul>"
    }
    return $html
}

proc Debug/parray {aname} {
    global $aname
    set html "<title>Array $aname</title>\n"
    append html "<H1>Array $aname</H1>\n"
    append html "<pre>[parray $aname]</pre>"
    return $html
}

proc Debug/raise {args} {
    error $args
}
proc Debug/goof {args} {
    set goof
}

proc Debug/after {} {
    global tcl_version
    set html "<title>After Queue</title>\n"
    append html "<H1>After Queue</H1>\n"
    append html "<pre>"
    if [catch {after info} afterlist] {
	append html "\"after info\" not supported in Tcl $tcl_version"
    } else {
	foreach a $afterlist {
	    append html "$a [after info $a]\n"
	}
    }
    append html </pre>
    return $html
}

proc Debug/echo {title args} {
    set html "<title>$title</title>\n"
    append html "<H1>$title</H1>\n"
    append html <dl>
    foreach {name value} $args {
	append html "<dt>$name<dd>$value"
    }
    append html </dl>
    return $html
}
proc Debug/errorInfo {title errorInfo} {
    set html "<title>$title</title>\n"
    append html "<H1>$title</H1>\n"
    append html "<p>[Version]"
    append html "<br>Webmaster: [Doc_Webmaster]"
    append html <pre>$errorInfo</pre>
    return $html
}

proc Debug/dbg {{host sage} {port 5000}} {
    global debug_init Httpd
    if {![info exist debug_init]} {
	if {[info command debugger_init] == ""} {
	    source $Httpd(library)/prodebug.tcl
	}
	debugger_init $host $port
	set debug_init "$host $port"
	return "Contacted TclPro debugger at $host:$port"
    } else {
	return "Already connected to tclPro at $debug_init"
    }
}
