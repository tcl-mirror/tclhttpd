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
exec tclsh8.2.3-t "$0" ${1+"$@"}

# Configure the auto_path so we can find the script library.
# In the source distribution it is in a peer directory of bin.
# It may also be in a "standard" location as a peer of the Tcl library.
# home is our location

set home [string trimright [file dirname [info script]] ./]
set home [file join [pwd] $home]
set Config(lib) [file join [file dirname $home] lib]
lappend auto_path $Config(lib)
set Config(home) $home
unset home

# Add operating-specific directories to the auto_path for
# the binary extensions

regsub -all { } $tcl_platform(os) {} tmp
foreach dir [list \
	[file join $Config(lib) Binaries $tmp] \
	[file join $Config(lib) Binaries $tmp $tcl_platform(osVersion)] \
	$Config(lib)] {
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
        [list -config       -any    [file join $Config(home) thread.rc]   {Configuration File}] \
        [list -library      -any    {}                              {Directory list where custom packages and auto loads are}] \
	[list -debug	    -boolean false			    {If true, start interactive command loop}] \
    ] {

    # Map the local variables defined by OptProc onto the globals used by the server
    global auto_path Config
    if {[string length $library]} {
	lappend auto_path $library
    }
    foreach var {docRoot port host ipaddr webmaster uid gid debug limit library} {
	set Config($var) [set $var]
    }
    set Config(file) $config 
}

eval _ProcessOptions $argv

# Load the configuration file, which is shared by all threads

if {[catch {source $Config(file)} message]} then {
    set error "Error processing configuration file \"[file nativename $Config(file)]\"."
    append error "\n\t" "Error was: $message"
    puts stderr $error
    exit 1
}
# Finally, start the server

Log_SetFile		/tmp/log$Config(port)_
Log_FlushMinutes	1

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

# Try to get TclX, if present
catch {load {} TclX}		;# From statically linked shell
catch {package require TclX}	;# From dynamically linked DLL
catch {package require setuid}	;# TclHttpd extension

if {"[info command id]" == "id"} {
    # Emulate TclHttpd C extension with TclX commands
    proc setuid {uid gid} {
	id userid $uid
	id groupid $gid
    }
}
if ![catch {
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
