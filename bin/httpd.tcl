#!/bin/sh
#
# This is the main script for an HTTP server. 
# To test out of the box, do
# tclsh httpd -debug
# or
# wish httpd -debug
#
# Ordinarily you'll want to
# edit this script to set various parameters, plus you'll
# want to set the path to wish or tclsh
# (Tcl 7.5 or higher is required,
# this works with the latest version of Tcl 8.0, too)
#
# For a quick spin, see the settings under QUICK START.
# For fully custom operation, see the settings under CONFIGURATION.
#
# Copyright (c) 1997 Sun Microsystems, Inc.
# Copyright (c) 1998 Scriptics Corporation
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# SCCS: @(#) httpd 1.17 97/12/15 09:21:53
#
# \
exec wish8.0 "$0" ${1+"$@"}

# Bootstrap the location of the script library.  This requires that
# the main httpd script be in a peer directory (e.g., ./bin and ./lib)
# home is our location
# Httpd(library) is where the script libraries are

set home [string trimright [file dirname [info script]] ./]
set home [file join [pwd] $home]
set Httpd(library) [file join [file dirname $home] lib]
lappend auto_path $Httpd(library)

#QUICK CONFIG
# The server comes with a URL tree under htdocs
set docRoot	[file join [file dirname $home] htdocs]
set port 	8015			;# 80 is standard, of course
set host 	[info hostname]		;# Server name, really
#set ipaddr	1.2.3.4			;# To bind to a specific interface
set webmaster	webmaster		;# An email address for errors
set uid		60001			;# Nobody, for setuid
set gid		50			;# web group, for setgid
set logDir	/tmp			;# Location of log files
#end QUICK

# Required modules
package require httpd			;# Protocol stack
package require html			;# Simple html generation
package require url			;# URL dispatching
package require auth			;# Basic authentication
package require counter			;# Statistics
package require mtype			;# Mime content types
package require stdin			;# command reader
package require utils			;# junk

# This automatically uses Tk for image maps and
# a simple control panel.  If you have a Tcl-only shell,
# then image maps hits are done differently and you
# don't get a control panel.
# You may need to tweak
# this if your Tcl shell can dynamically load Tk
# because tk_version won't be defined, but it could be.

if [info exists tk_version] {
    # Use a Tk canvas for imagemap hit detection
    package require ismaptk
    # Display Tk control panel
    package require srvui
} else {
    # Do imagemap hit detection in pure Tcl code
    package require ismaptcl
}

# These packages are required for "normal" web servers

package require doc		;# Basic file URLS
package require include		;# Server side includes
#package require safetcl	;# Safe tcl in external process (broken)
package require cgi		;# Standard CGI
package require log		;# Logging
package require dirlist		;# Directory listings

# These packages are for special things built right into the server

package require direct		;# Application Direct URLs
package require status		;# Built in status counters
package require admin		;# Url-based administration
package require mail		;# Crude email support
package require session		;# Session state module (better Safe-Tcl)

# Debugging support

package require debug		;# /debug URL tree
package require opentrace	;# wrapper for open command
catch {source $Httpd(library)/prodebug.tcl}     ;# Tcl-Pro nub

# These packages are for the SNMP demo application

if [catch {
package require snmp		;# SNMP form creation
package require Tnm		;# Low level network stuff
Snmp_SessionPage /snmp/host.snmp?session=new	;# Default start page
}] {
    catch {puts stderr "No SNMP support"}
}

# This call defines a few default settings
Httpd_Init

# CONFIGURATION
# You may want adjust these parameters.
# For information about these calls, see htdocs/reference.html

Doc_Root                $docRoot
Doc_IndexFile           index.{tml,html,shtml,thtml,htm,subst}
Doc_PublicHtml          public_html
Cgi_Directory           /cgi-bin
Status_Url              /status
Debug_Url               /debug
Mail_Url                /mail
Admin_Url               /admin
Doc_TemplateInterp      {}
Doc_CheckTemplates      1
Doc_TemplateLibrary     $docRoot/libtml
Doc_ErrorPage           /error.html
Doc_NotFoundPage        /notfound.html
Doc_Webmaster           $webmaster
if [catch {Auth_AccessFile              .htaccess} err] {
    Stderr "No Basic Authentication: $err"
}
Log_SetFile             $logDir/log${port}_
Log_FlushMinutes        1

#END CONFIGURATION

# This is what I do for site-wide look and feel
catch {
    package require template
    source $docRoot/.tml
}

# Start the server listening on the accept socket.
# If you have defined ipaddr, it binds to that interface.
# Otherwise it accepts connections on any interface.

if {[catch {
    if [info exists ipaddr] {
	Httpd_Server 	$port $host $ipaddr
    } else {
	Httpd_Server 	$port $host
    }
}]} {
    # try other ports
    for {set port 8000} {1} {incr port} {
        if ![catch {
            Httpd_Server $port $host
        }] {
            puts stderr "Httpd on [info hostname]:$port"
            Log_SetFile $logDir/log${port}_
            break
        }
    }
}
Log_Flush

# Try to increase file descriptor limits
 
if {[catch {
    package require limit
    set limit 256
    limit $limit
}]} {
    set limit default
}
Stderr "Running with $limit file descriptor limit"
 
# Try to change UID to nobody

if ![catch {
    package require setuid
    setuid $uid
}] {
    Stderr "Running as user $uid"
}

# Start up the user interface and event loop.

if [info exists tk_version] {
    SrvUI_Init "Tcl HTTPD $Httpd(version)"
}
catch {puts stderr "httpd started on port $port"}
if {[lsearch -glob $argv -de*] >= 0} {
    # Enter interactive command loop, then exit.  Otherwise run forever.
    Stdin_Start "httpd % "
    Httpd_Shutdown
} else {
    vwait forever
}
