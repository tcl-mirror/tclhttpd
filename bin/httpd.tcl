#!/bin/sh
#
# Tcl HTTPD
#
# This is the main script for an HTTP server. 
# To test out of the box, do
# tclsh httpd -debug
# or
# wish httpd -debug
#
# Ordinarily you'll not want to edit this file.
# For a quick spin, just pass the appropriate settings via the command line.
# For fully custom operation, copy tclhttpd.rc to your own configuration file,
# modify it, and specify it as the value of the -config command line option.
#
# Tcl 7.5 or higher is required, this works with the latest version of Tcl 8.0, too
#
#
# Copyright (c) 1997 Sun Microsystems, Inc.
# Copyright (c) 1998 Scriptics Corporation
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# \
exec tclsh8.0 "$0" ${1+"$@"}

# Configure the auto_path so we can find the script library.
# It the source distribution it is in a peer directory of bin.
# It may also be in a "standard" location as a peer of the Tcl library.
# home is our location

set home [string trimright [file dirname [info script]] ./]
set home [file join [pwd] $home]
lappend auto_path [file join [file dirname $home] lib]
set Config(home) $home
unset home

# Add operating-specific directories to the auto_path for
# the binary extensions

regsub -all { } $tcl_platform(os) {} tmp
foreach dir [list \
	[file join $Httpd(library) Binaries $tmp] \
	[file join $Httpd(library) Binaries $tmp $tcl_platform(osVersion)] \
	$Httpd(library)] {
    if {[file isdirectory $dir]} {
	lappend auto_path $dir
    }
}
unset tmp dir

#
# Define the command line option processing procedure
# The options are mapped into elements of the Config array
#
package require opt
::tcl::OptProc _ProcessOptions [list \
        [list -docRoot      -any    [file join [file dirname $Config(home)] htdocs]      {Root directory for documents}] \
        [list -port         -int    8015                              {Port number server is to listen on}] \
        [list -host         -any    [info hostname]                 {Server name, should be fully qualified}] \
        [list -ipaddr       -any    {}                              {Interface server should bind to}] \
        [list -webmaster    -any    webmaster@[info hostname]       {E-mail address for errors}] \
        [list -uid          -int    50                              {User Id that server ans scripts are to run under}] \
        [list -gid          -int    100                             {Group Id for caching templates}] \
        [list -limit        -int    256                              {File descriptor limit}] \
        [list -config       -any    [file join $Config(home) tclhttpd.rc]   {Configuration File}] \
        [list -library      -any    {}                              {Directory list where custom packages and auto loads are}] \
	[list -debug	    -boolean false			    {If true, start interactive command loop}] \
    ] {

    # Map the local variables defined by OptProc onto the globals used by the server
    global auto_path Config
    if {[string length $library]} {
	lappend auto_path $library
    }
    foreach var {docRoot port host ipaddr webmaster uid gid debug limit} {
	set Config($var) [set $var]
    }
    set Config(file) $config 
}

eval _ProcessOptions $argv

# Core modules
package require httpd           ;# Protocol stack
package require html            ;# Simple html generation
package require url		;# URL dispatching
package require counter         ;# Statistics
package require mtype           ;# Mime content types
package require utils           ;# junk

#  Not strictly required, but nearly always used
package require auth            ;# Basic authentication
package require log             ;# Standard loggin

# When debugging, a command reader is helpful
if {$Config(debug)} {
    if {[catch {package require stdin}]} {
	puts "No command loop available"
	set debug 0
    }
}

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

# This initializes some state, but doesn't start the server yet.
# Do this before loading the configuraiton file.

Httpd_Init

if {[catch {source $Config(file)} message]} then {
    set error "Error processing configuration file \"[file nativename $Config(file)]\"."
    append error "\n\t" "Error was: $message"
    puts stderr $error
    exit 1
}

# Finally, start the server

Httpd_Server $Config(port) $Config(host) $Config(ipaddr)

Log_Flush

# Try to increase file descriptor limits

if [catch {
    package require limit
    limit $Config(limit)
} err] {
    Stderr $err
    set Config(limit) default
}
Stderr "Running with $Config(limit) file descriptor limit"

# Try to change UID to tclhttpd so we can write template caches

if ![catch {
    package require setuid
    setuid $Config(uid) $Config(gid)
}] {
    Stderr "Running as user $Config(uid)"
}

# Start up the user interface and event loop.

if {[info exists tk_version]} {
    SrvUI_Init "Tcl HTTPD $Httpd(version)"
}
if {$Config(debug)} {
    # Enter interactive command loop, then exit.  Otherwise run forever.
    Stdin_Start "httpd % "
    Httpd_Shutdown
} else {
    catch {puts stderr "httpd started on port $Config(port)"}
    vwait forever
}
