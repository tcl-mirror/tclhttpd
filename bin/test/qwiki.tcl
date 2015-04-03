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
    array set result {
      code 200
      type text/html
    }
    set body {
<HTML><BODY>
Hello World!
<p>
    }
    append body "Logged in as user: [dict getnull $result(session) username]<br>"
    if {[info exists result(sessionid)]} {
      append body "Logged with session: $result(sessionid)<br>"
    }
    append body {
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

