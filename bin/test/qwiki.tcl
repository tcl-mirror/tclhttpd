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
set Config(MainDatabaseFile) [file join $home test qwiki.sqlite]
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
  method /html resultObj {
    $resultObj configure title {Welcome to Qwiki!}

    $resultObj puts [my pageHeader]
    $resultObj puts {
Hello World!
<p>
    }
    $resultObj puts "Logged in as user: [$resultObj session get username]<br>"
    $resultObj puts "Logged with session: [$resultObj cget sessionid]<br>"
    $resultObj puts {
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
      $resultObj puts "<li><a href=$prefix/$url>$url</a> - $comment</li>"
    }
    $resultObj puts {</ul>}
    $resultObj puts [my pageFooter]
  }

  method /html/errorurl resultObj {
    error "Die Yuppie Scum!"
  }

  method /html/deadurl resultObj {
    $resultObj configure title {Page Error!}
    $resultObj configure code 501
    $resultObj puts [my pageHeader]
    $resultObj puts {
I threw an error this way
    }
    $resultObj puts [my pageFooter]
  }

  ###
  # title: Implement html content at a toplevel
  ###
  method /html/suburl resultObj {
    $resultObj configure title {Sub Url!}
    $resultObj puts [my pageHeader]
    $resultObj puts {Sub Url}
    $resultObj puts "<p><a href=\"[my cget virtual]\">Back</a>"
    $resultObj puts [my pageFooter]
  }

  ###
  # title: Implement html content at a toplevel
  ###
  method /html/default resultObj {
    $resultObj configure title {Not Found}
    $resultObj configure code 404
    $resultObj puts [my pageHeader]
    $resultObj puts "The page: [$resultObj cgi get REQUEST_URI] coult not be cound"
    $resultObj puts "<p><a href=\"[my cget virtual]\">Back</a>"
    $resultObj puts [my pageFooter]
  }
}

qwikitest create HOME /home [list filename [Config MainDatabaseFile]]
HOME task_daily

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

