# cgi.tcl
# CGI support
# Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) cgi.tcl 1.15 97/07/11 16:24:41

package provide cgi 1.1

# init support

array set Cgi {
    timeout	300000
    maxcgi	100
    cgi		0
    ident	0
}

# Register a cgi-bin directory.
# This causes the server to pay attention to the extra path information
# after the program name.

proc Cgi_Directory {virtual {directory {}}} {
    if {[string length $directory] == 0} {
	set directory [Doc_Virtual {} {} $virtual]
    }
    Url_PrefixInstall $virtual [list Cgi_Domain $directory]
}

# Cgi_Domain is called from Url_Dispatch for URLs inside cgi-bin directories.

proc Cgi_Domain {directory sock suffix} {
    global Cgi env
    # Check the path and then find the part beyond the program name.
    if [catch {Url_PathCheck $suffix} pathlist] {
	Doc_NotFound $sock
	return
    }
    set path $directory
    set i 0
    foreach component $pathlist {
	incr i
	set path [file join $path $component]
	if {[file isfile $path]} {
	    if {[file executable $path]} {
		set extra [lrange $pathlist $i end]
	    }
	    break
	} elseif {![file exists $path]} { 
	    Doc_NotFound $sock
	    return
	}
    }
    if ![info exists extra] {
	# Didn't find an executable file
	Httpd_Error $sock 403
	return
    }
    # The CGI needs the script, the extra part after the program name,
    # and the translated version of the whole pathname.

    Url_Handle [list CgiHandle $path /[join $extra /] \
	    [eval {file join $directory} $pathlist]] $sock
}

proc CgiHandle {path extra translated sock} {
    global Doc
    Cgi_SetEnvAll $sock $path $extra $translated env
    CgiSpawn $sock $path
}

# This gets called if there is no extra pathname after
# the name of a cgi script, and the Doc module finds a .cgi file

proc Doc_application/x-cgi {path suffix sock} {
    Url_Handle [list CgiHandle $path {} $path] $sock
}

# Set the environment for the cgi scripts.  This is passed implicitly to
# the cgi script during the "open" call.

proc Cgi_SetEnv {sock path {var env}} {
    Cgi_SetEnvAll $sock $path {} $path $var
}

proc Cgi_SetEnvAll {sock path extra translated var} {
    upvar #0 Httpd$sock data
    upvar #0 $var env
    global Httpd Httpd_EnvMap Cgi

    # we can't "unset env" or it won't get passed to the CGI script
    foreach i [array names env] {
	unset env($i)
    }
    foreach name [array names Httpd_EnvMap] {
	set env($name) ""
	catch {
	    set env($name) $data($Httpd_EnvMap($name))
	}
    }
    set env(GATEWAY_INTERFACE) "CGI/1.1"
    set env(SERVER_PORT) $Httpd(port)
    set env(SERVER_NAME) $Httpd(name)
    set env(SERVER_SOFTWARE) $Httpd(server)
    set env(SERVER_PROTOCOL) HTTP/1.0
    set env(REMOTE_ADDR) $data(ipaddr)
    set env(SCRIPT_NAME) [string range $path [string length [Doc_Root]] end]
    set env(PATH_INFO) $extra
    set env(PATH_TRANSLATED) $translated
    set env(DOCUMENT_ROOT) [Doc_Root]
    set env(HOME) [Doc_Root]

    if {$Cgi(ident)} {
	catch {
	    set ident [::ident::get $sock]
	    set env(REMOTE_IDENT) [lindex $ident 0]
	}
    }

    if {$data(proto) == "POST"} {
	set env(QUERY_STRING) ""
    }
}

# Enable/disable IDENT lookup.  Disabled by default.

proc Cgi_Ident state {
    global Cgi

    regsub {^(1|yes|true|on)$} $state 1 state
    regsub {^(0|no|false|off)$} $state 0 state

    if {$state} {
	package require ident
    }

    set Cgi(ident) $state
}

# Run a cgi script:
# Our caller needs to set up the environment with Cgi_SetEnv.
# Run the script, and copy the
# output to the socket. 
# Set a timer to deal with invalid scripts.

proc CgiSpawn {sock script} {
    upvar #0 Httpd$sock data
    global env Cgi

    if {$Cgi(cgi) >= $Cgi(maxcgi)} {
	Httpd_Error $sock 504  "Too many CGI's"
	return
    }
    incr Cgi(cgi)

    # for GET queries, pass the query as an argument to the cgi script
    if {$data(proto) == "POST"} {
	set arglist ""
    } else {
	set arglist $data(query)
    }
    set pwd [pwd]
    cd [file dirname $script]
    if {[catch {open "|$script $arglist |& cat" r+} fd]} {
	cd $pwd
	Httpd_Error $sock 400 $fd
	incr Cgi(cgi) -1
	return
    }
    cd $pwd
    Count cgihits
    set data(infile) $fd	;# So close happens in Httpd_SockClose
    fconfigure $fd -blocking 0
    # it might be better to look at "content length" instead.
    if {$data(proto) == "POST"} {
	puts $fd $data(query)
	flush $fd
    }
    fileevent $sock readable [list CgiCleanup $fd $sock]
    fileevent $fd readable [list CgiRead $fd $sock]
    set data(cancel) [after $Cgi(timeout) CgiCancel $fd $sock]
}


# Read data from the CGI script, write to client.

proc CgiRead {fd sock} {
    upvar #0 Httpd$sock data
    global Cgi Httpd
    if {[eof $fd]} {
	CgiClose $fd $sock
    } elseif {[catch {
	# Socket may have gone away
	if {![info exists data(header)]} {
	    puts $sock "HTTP/1.0 200 data follows"
	    puts $sock "Server: $Httpd(server)"
	    puts $sock "Date: [HttpdDate [clock seconds]]"
	    puts $sock "Connection: Close"
	    set data(header) 1
	}
	fconfigure $fd -translation binary
	fconfigure $sock -translation binary
	if {$Httpd(fcopy)} {
	    fileevent $fd readable {}
	    fcopy $fd $sock -command [list CgiClose $fd $sock]
	} else {
	    fconfigure $sock -blocking 0
	    copychannel $fd $sock
	}
    } oops]} {
	CgiCancel $fd $sock
    }
}

proc CgiClose {fd sock {bytes {}} {error {}}} {
    global Cgi
    upvar #0 Httpd$sock data
    catch {after cancel $data(cancel)}
    incr Cgi(cgi) -1
    if {![info exists data(header)]} {
	Httpd_Error $sock 204
    } else {
	Httpd_SockClose $sock 1
    }
    if {[string length $error] > 0} {
	Log $sock CgiClose $error
    }
}

# Cancel a cgi script if it is taking too long.

proc CgiCancel {fd sock} {
    upvar #0 Httpd$sock data

    Log $sock CgiCancel $data(url)
    catch {exec kill [pid $fd]}
    CgiClose $fd $sock
}

# This is installed after running the sub-process to
# check for eof on the socket before the processing is complete.

proc CgiCleanup {fd sock} {
    fconfigure $sock -blocking 0 -translation auto
    set n [gets $sock line]
    if [eof $sock] {
	CgiCancel $fd $sock
    }
}


