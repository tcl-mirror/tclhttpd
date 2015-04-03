#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}

############
# auto_path
############

# Configure the auto_path so we can find the script library.
# home is the directory containing this script

set home [string trimright [file dirname [info script]] ./]
set home [file normalize [file join [pwd] $home ..]]
set Config(lib) [file join $home .. modules]
set Config(dbfile) [file join $home test qwiki.sqlite]
source $home/test/common.tcl

###
# Begin the test
###
package require httpd::qwiki

tao::class qwikitest {
  superclass httpd.qwiki

  ###
  # title: Implement html content at a toplevel
  ###
  method /html {} {
    my variable result
    my reset
    set result(title) {Welcome to Qwiki!}

    my puts [my pageHeader]
    my puts {
Hello World!
<p>
    }
    my puts "Logged in as user: [dict getnull $result(session) username]<br>"
    if {[info exists result(sessionid)]} {
      my puts "Logged with session: $result(sessionid)<br>"
    }
    my puts {
Try the following links:
<ul>
    }
    set prefix [my cget virtual]
    foreach {url comment} {
      errorurl {Throw an internal error from Tcl}
      deadurl  {Page that generates a 505 error}
      suburl   {Valid Suburl}
      missing  {Non-existent url}
      login    {Log In}
      logout   {Log Out}
    } {
      my puts "<li><a href=$prefix/$url>$url</a> - $comment</li>"
    }
    my puts {
</ul>
</BODY></HTML>
}
  }

  method /html/errorurl {} {
    error "Die Yuppie Scum!"
  }

  method /html/deadurl {} {
    my variable result
    my reset
    set result(code) 501
    my puts [my pageHeader]
    my puts {
I threw an error this way
    }
    my puts [my pageFooter]
  }

  ###
  # title: Implement html content at a toplevel
  ###
  method /html/suburl {} {
    my variable result
    my reset
    my puts [my pageHeader]
    my puts {
This is a suburl!
    }
    my puts [my pageFooter]
  }

  ###
  # title: Implement html content at a toplevel
  ###
  method /html/default {} {
    my variable result
    my reset
    set result(code) 404
    my puts [my pageHeader]
    my puts {
Not Found
    }
    my puts [my pageFooter]
  }
}

qwikitest create HOME /home [list dbfile [Config dbfile]]

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

