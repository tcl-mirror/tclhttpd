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

source $home/test/common.tcl

###
# Test for DirectOO
###
package require httpd::directoo

oo::class create ootest {
  superclass httpd.url

  ###
  # title: Implement html content at a toplevel
  ###
  method /html resultObj {
    $resultObj configure title {Welcome!}
    $resultObj puts [my pageHeader]
    $resultObj puts {
Hello World!
<p>
Try the following links:
<ul>
    }
    set prefix [$resultObj cget url_prefix]
    foreach {url comment} {
      errorurl {Throw an internal error from Tcl}
      deadurl  {Page that generates a 505 error}
      suburl   {Valid Suburl}
      missing  {Non-existent url}
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
    $resultObj puts "The page: [$resultObj cgi get REQUEST_URI] coult not be cound}
    $resultObj puts "<p><a href=\"[my cget virtual]\">Back</a>"
    $resultObj puts [my pageFooter]
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

