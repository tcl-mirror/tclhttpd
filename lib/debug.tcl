# debug.tcl --
#
#	Application-direct URLs to help debugg the server.
# 	Tcl procedures of the form Debug/hello implement URLS
#	of the form /debug/hello
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: debug.tcl,v 1.9 2000/08/02 07:06:52 welch Exp $

package provide httpd::debug 1.0

proc Debug_Url {dir} {
    Direct_Url $dir Debug
}

# Debug/source --
#
#	Source the file into a server thread.  First look for the file to
#	source in the dir specified by Httpd(library).  If not found, use the
#	dir in Doc(templateLibrary).
#
# Arguments:
#	source	the file to source
#
# Results:
#	Returns HTML code that displays result of loading the file.

proc Debug/source {source {thread main}} {
    global Httpd Doc
    set source [file tail $source]
    set dirlist $Httpd(library)
    if {[info exists Doc(templateLibrary)]} {
	lappend dirlist $Doc(templateLibrary)
    }
    foreach dir $dirlist {
	set file [file join $dir $source]
	if {[file exists $file]} {
	    break
	}
    }
    set error [catch {
	switch -- $thread {
	    main {
		uplevel #0 [list source $file]
	    }
	    all {
		foreach id [Thread_List] {
		    Thread_Send $id [list source $file]
		}
	    }
	    default {
		    Thread_Send $thread [list source $file]
	    }
	}
    } result]
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

# Debug/package --
#
#	Forget, delete, and the reload a package into the server.
#
# Arguments:
#	name	the package to reload.
#
# Results:
#	Returns HTML code that displays the result of reloading the package.

proc Debug/package {name} {
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
 
# Debug/pvalue --
#
#	Generate HTML code that displays the contents of all existing arrays
#	and variables that match the glob pattern.
#
# Arguments:
#	aname	the (fully qualified) glob pattern to match against existing
#		arrays and variables.
#
# Results:
#	Returns HTML code that displays the contents of the arrays and
#	variables that match the glob pattern.

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

# Debug/parray --
#
#	Generate HTML code that displays 
#
# Arguments:
#	aname	the name of the array whose contents will appear.
#
# Results:
#	Returns HTML code that displays 

proc Debug/parray {aname} {
    global $aname
    set html "<title>Array $aname</title>\n"
    append html "<H1>Array $aname</H1>\n"
    append html "<pre>[parray $aname]</pre>"
    return $html
}

# Debug/raise --
#
#	Generate HTML code that causes the Tcl error specified by args to be thrown.
#
# Arguments:
#	args	(optional) the error string to throw.
#
# Side Effects:
#	An error is thrown.
#
# Results:
#	none.

proc Debug/raise {args} {
    error $args
}

# Debug/goof --
#
#	Generate HTML code that causes the Tcl error: "can't read "goof": no
#	such variable".
#
# Arguments:
#	none.
#
# Side Effects:
#	An error is thrown.
#
# Results:
#	None.

proc Debug/goof {} {
    set goof
    return
}

# Debug/after --
#
#	Generate HTML code that displays info regarding after events existing
#	on the server.
#
# Arguments:
#	none.
#
# Results:
#	Returns HTML.

proc Debug/after {} {
    global tcl_version
    set html "<title>After Queue</title>\n"
    append html "<H1>After Queue</H1>\n"
    append html "<pre>"
    if {[catch {after info} afterlist]} {
	append html "\"after info\" not supported in Tcl $tcl_version"
    } else {
	foreach a $afterlist {
	    append html "$a [after info $a]\n"
	}
    }
    append html </pre>
    return $html
}

# Debug/echo --
#
#	Generate HTML code that displays the attributes and values posted to
#	the URL.
#
# Arguments:
#	title	(optional) title to display
#	args	an even number of attrbutes and values to be displayed.
#
# Results:
#	Returns HTML.

proc Debug/echo {title args} {
    set html "<title>$title</title>\n"
    append html "<H1>$title</H1>\n"
    append html "<table border=1>\n"
    foreach {name value} $args {
	append html "<tr><td>$name</td><td>$value</td></tr>\n"
    }
    append html </table>
    return $html
}

# Debug/errorInfo --
#
#	Generate HTML code that displays a title, some errorInfo, and the
#	contents of (the env) array.
#
# Arguments:
#	title		(optional) page title to display
#	errorInfo	(optional) error data to display
#	env		(optional) the name of an array to display
#
# Results:
#	Returns HTML.

proc Debug/errorInfo {title errorInfo {env {no environment}}} {
    set html "<title>$title</title>\n"
    append html "<H1>$title</H1>\n"
    append html "<p>[Version]"
    append html "<br>Webmaster: [Doc_Webmaster]"
    append html <pre>$errorInfo</pre>
    append html "<p>Environment:</p>"
    append html "<table>"
    catch {
    array set X $env
    foreach n [lsort [array names X]] {
	append html "<tr><td>$n</td><td>$X($n)</td></tr>\n"
    }
    }
    append html "</table>"
    return $html
}

# Debug/dbg --
#
#	Initiate a connection with the tcldebugger.
#
# Arguments:
#	host	the host where the debugger is running
#	port	the port on which the debugger is listening
#
# Results:
#	Returns the result of initiating the connection in HTML.

proc Debug/dbg {host port} {
    global debug_init Httpd
    if {![info exist debug_init]} {
	if {[info command debugger_init] == ""} {
	    source [file join $Httpd(library) prodebug.tcl]
	}
	debugger_init $host $port
	set debug_init "$host $port"
	return "Contacted TclPro debugger at $host:$port"
    }
    return "Already connected to tclPro at $debug_init"
}

# Debug/showproc --
#
#	Generate HTML code that displays the args and body of a proc.
#
# Arguments:
#	proc	the name of the procedure
#
# Results:
#	Returns HTML.

proc Debug/showproc {proc} {
    global Debug/showproc
    set Debug/showproc text/plain

    set alist ""
    foreach arg [info args $proc] {
        if {[info default $proc $arg default]} {
            set arg [list $arg $default]
        }
        lappend alist $arg
    }
    return [list proc $proc $alist [info body $proc]]
}
