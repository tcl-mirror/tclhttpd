###
# Test for DirectOO
###
#!/bin/sh
#
# Tcl HTTPD
#
# This is the main script for an HTTP server. 
# To test out of the box, do
# tclsh httpd.tcl -debug 1
# or
# wish httpd.tcl -debug 1
#
# For a quick spin, just pass the appropriate settings via the command line.
# For fully custom operation, see the notes in README_custom.
#
# A note about the code structure:
# ../lib	The script library that contains most of the TclHttpd
#		implementation
# ../tcllib	The Standard Tcl Library.  TclHttpd ships with a copy
#		of this library because it depends on it.  If you already
#		have copy installed TclHttpd will attempt to find it.
#
# TclHttpd now requires Tcl 8.0 or higher because it depends on some
#	modules in the Standard Tcl Library (tcllib) that use namespaces.
#	In practice, some of the modules in tcllib may depend on
#	new string commands introduced in Tcl 8.2 and 8.3.  However,
#	the server core only depends on the base64 and ncgi packages
#	that may/should be/are compatible with Tcl 8.0
#
# Copyright (c) 1997 Sun Microsystems, Inc.
# Copyright (c) 1998-2000 Scriptics Corporation
# Copyright (c) 2001-2002 Panasas
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: httpd.tcl,v 1.61 2006/04/27 00:24:51 wart Exp $
#
# \
exec tclsh "$0" ${1+"$@"}

############
# auto_path
############

# Configure the auto_path so we can find the script library.
# home is the directory containing this script

set home [string trimright [file dirname [info script]] ./]
set home [file normalize [file join [pwd] $home ..]]
set Config(lib) [file join $home .. lib]

# Auto-detect the configuration
# 1. Development - look for $home/../lib and $home/../../tcllib/modules
# 2. Standalone install - look for $home/../lib/tclhttpd $home/tcllib
# 3. Tcl package install - look for $tcl_library/../tclhttpd

set v 4.0.0

# Put the library in front in case there is both the development
# library and an installed library

set auto_path [concat [list $Config(lib)] $auto_path]

# Search around for the Standard Tcl Library
# We used to require "tcllib", but that now causes complaints
# Tcllib 1.6 has inconsistencies with md5 1.4.3 and 2.0.0,
# and requiring 1.0 cures later conflicts with 2.0

if {![catch {package require md5 1}]} {
    # Already available in environment
} elseif {[file exist [file join $home ../tcllib]]} {
    lappend auto_path [file join $home ../tcllib]
} else {
    # Look for the CVS development sources
    set cvs [lindex [lsort -decreasing \
	[glob -nocomplain [file join $home ../../tcllib*]]] 0]
    if {[file exist [file join $cvs modules]]} {
	lappend auto_path [file join $cvs modules]
    } elseif {[file exist [file join $cvs pkgIndex.tcl]]} {
	lappend auto_path $cvs
    } else {
	error "Cannot find Standard Tcl Library in auto_path:\n[join $auto_path \n]"
    }
}

set Config(home) $home
unset home

# Add operating-specific directories to the auto_path for
# the binary extensions

regsub -all { } $tcl_platform(os) {} tmp
foreach dir [list \
	[file join $Config(lib) Binaries $tmp] \
	[file join $Config(lib) Binaries $tmp $tcl_platform(osVersion)] \
	] {
    if {[file isdirectory $dir]} {
	lappend auto_path $dir
    }
}
unset tmp dir

proc ::Config {field args} {
  switch {[llength $args]>1} {
    error "Usage: Config field ?value?"
  }
  global Config
  if {[llength $args]} {
    set Config($field) [lindex $args 0]
  }
  if {[info exists Config($field)]} {
    return $Config($field)
  }
}
##############
# Config file
##############

# Load the configuration file into the Config array
# First, we preload a couple of defaults

set Config(docRoot) [file join [file dirname [Config home]] htdocs]
set Config(library) [file join [file dirname [Config home]] custom]
set Config(main) [file join [Config home] httpdthread.tcl]
set Config(debug) 0
set Config(compat) 3.3

# The configuration bootstrap goes like this:
# 1) Look on the command line for a -config rcfile name argument
# 2) Load this configuration file via the config module
# 3) Process the rest of the command line arguments so the user
#       can override the settings in the rc file with them.

set ix [lsearch $argv -config]
if {$ix >= 0} {
    incr ix
    set Config(config) [lindex $argv $ix]
} else {
    set Config(config) [file join [Config home] tclhttpd.rc]
}

package require httpd 1.6
package require httpd::version		;# For Version proc
package require httpd::utils		;# For Stderr
package require httpd::counter		;# For Count
package require fileutil                ;# For tempdir support: needed on Windows

package require httpd::config		;# for config::init


proc ::cget {field} {
  global Config
  if {[info exists Config($field)]} {
    return $Config($field)
  }
}
proc ::DebugCheckRandomPassword input {
  return 1
}
array set Config {
  debug 1
  port 8015
  https_port	8016
  uid 50
  gid 50
  ipaddr {}
  https_ipaddr {}
  secsPerMinute	60
  threads 0
  gui        1
LogFlushMinutes 0
LogDebug 0
CompressProg gzip
MaxFileDescriptors	256
SSL_REQUEST	0
SSL_REQUIRE	0
SSL_CAFILE 	""
}
Config docroot [file join [Config home] .. htdocs]
Config library [file join [Config home] .. custom]
Config main [file join [Config home]  httpdthread.tcl]
Config host [info hostname]
Config https_host [info hostname]
Config webmaster	webmaster@[info hostname]
Config LogFile [file join [::fileutil::tempdir] log]
Config SSL_CADIR	[file join [file dirname [Config home]] certs])
Config SSL_CERTFILE	[file join [Config SSL_CADIR] server.pem]
Config MailServer {}
# The Config array now reflects the info in the configuration file

#########################
# command line arguments
#########################

# Override config file settings with command line arguments.
# The CommandLineOptions global is known to some of the
# web pages that document the server.

package require cmdline
set CommandLineOptions [list \
        [list virtual.arg      [cget virtual]      {Virtual host config list}] \
        [list config.arg       [cget config]       {Configuration File}] \
        [list main.arg         [cget main]         {Per-Thread Tcl script}] \
        [list docRoot.arg      [cget docRoot]      {Root directory for documents}] \
        [list port.arg         [cget port]         {Port number server is to listen on}] \
        [list host.arg         [cget host]         {Server name, should be fully qualified}] \
        [list ipaddr.arg       [cget ipaddr]       {Interface server should bind to}] \
        [list https_port.arg   [cget https_port]   {SSL Port number}] \
        [list https_host.arg   [cget https_host]   {SSL Server name, should be fully qualified}] \
        [list https_ipaddr.arg [cget https_ipaddr] {Interface SSL server should bind to}] \
        [list webmaster.arg    [cget webmaster]    {E-mail address for errors}] \
        [list uid.arg          [cget uid]          {User Id that server runs under}] \
        [list gid.arg          [cget gid]          {Group Id for caching templates}] \
        [list secs.arg          [cget secsPerMinute] {Seconds per "minute" for time-based histograms}] \
        [list threads.arg      [cget threads]      {Number of worker threads (zero for non-threaded)}] \
        [list library.arg      [cget library]      {Directory list where custom packages and auto loads are}] \
        [list debug.arg	       0	        {If true, start interactive command loop}] \
        [list compat.arg       3.3	        {version compatibility to maintain}] \
        [list gui.arg           [cget gui]      {flag for launching the user interface}] \
        [list mail.arg           [cget MailServer]      {Mail Servers for sending email from tclhttpd}] \
        [list daemon.arg        0      		   {Run in the background as a daemon process.  Requires the 'Expect' package.}] \
    ]
array set Config [cmdline::getoptions argv $CommandLineOptions \
    "usage: httpd.tcl options:"]

if {[string length $Config(library)]} {
    lappend auto_path $Config(library)
}

if {$Config(debug)} {
    puts stderr "auto_path:\n[join $auto_path \n]"
    if {[catch {package require httpd::stdin}]} {
	puts "No command loop available"
	set Config(debug) 0
    }
}

if {$Config(compat)} {
    if {[catch {package require httpd::compat}]} {
	puts stderr "tclhttpd$Config(compat) compatibility mode failed."
    } else {
	# Messages here just confuse people
    }
}

###################
# Start the server
###################

Httpd_Init
#Counter_Init $Config(secs)

# Open the listening sockets
Httpd_Server $Config(port) $Config(host) $Config(ipaddr)
append startup "httpd started on port $Config(port)\n"

if {[catch {source $Config(main)} message]} then {
    global errorInfo
    set error "Error processing main startup script \"[file nativename $Config(main)]\"."
    append error "\n$errorInfo"
    error $error
}

# The main thread owns the log

Log_CompressProg	[cget CompressProg]
Log_SetFile		[cget LogFile]$Config(port)_
Log_FlushMinutes	[cget LogFlushMinutes]
Log_Flush


###
# Begin the test
###
package require httpd::directoo

oo::class create ootest {
  superclass httpd.url

  ###
  # title: Implement html content at a toplevel
  ###
  method /html {} {
    my variable result
    array set result {
      code 200
      type text/html
    }
    set body {
<HTML><BODY>
Hello World!
<p>
Try the following links:
<ul>
    }
    set prefix [my cget virtual]
    foreach {url comment} {
      errorurl {Throw an internal error from Tcl}
      deadurl  {Page that generates a 505 error}
      suburl   {Valid Suburl}
      missing  {Non-existent url}
    } {
      append body "<li><a href=$prefix/$url>$url</a> - $comment</li>"
    }
    append body {
</ul>
</BODY></HTML>
}
    set result(body) $body
  }

  method /html/errorurl {} {
    error "Die Yuppie Scum!"
  }

  method /html/deadurl {} {
    my variable result
    array set result {
      code 501
      body {
<HTML><BODY>
I threw an error this way
</BODY></HTML>
}
      content-type text/html
    }
  }

  ###
  # title: Implement html content at a toplevel
  ###
  method /html/suburl {} {
    my variable result
    array set result {
      code 200
      body {
<HTML><BODY>
Sub Url
</BODY></HTML>
}
      type text/html
    }
  }

  ###
  # title: Implement html content at a toplevel
  ###
  method /html/default {} {
    my variable result
    array set result {
      code 404
      body {
<HTML><BODY>
Not Found
</BODY></HTML>
}
      type text/html
    }
  }
}
ootest create OOTEST /ootest {}

vwait forever
if 0 {
# Start up the user interface and event loop.
package require Tk
package require httpd::srvui
package require httpd::stdin
SrvUI_Init "Tcl HTTPD $Httpd(version)"
Stderr $startup
if {[info commands "console"] == "console"} {
    console show
} else {
    Stdin_Start "httpd % "
    Httpd_Shutdown
}
}

