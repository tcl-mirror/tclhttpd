# srvui.tcl
# Trivial Tk control panel for the server.
#
# Brent Welch  (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) srvui.tcl 1.3 97/06/26 15:10:51

package provide srvui 1.0

proc SrvUI_Init {title} {
    global Httpd Doc
    option add *font 9x15
    
    wm title . $Httpd(name):$Httpd(port)
    wm protocol . WM_DELLETE_WINDOW {Httpd_Shutdown; exit}
    wm iconname . $Httpd(name):$Httpd(port)
    message .msg -text "$title\n$Httpd(name):$Httpd(port)\n$Doc(root)" -aspect 1000
    grid .msg -columnspan 2 -sticky news

    foreach {counter label} {
	    urlhits "URL Requests"
	    urlreply "URL Replies"
	    cgihits "CGI Hits"
	    tclhits "Tcl Safe-CGIO Hits"
	    maphits "Image Map Hits"
	    errors	"Errors"
	    } {
	label .l$counter -text $label
	label .n$counter -textvariable counter($counter) -width 0
	grid .l$counter .n$counter -sticky w
	grid configure .n$counter -sticky e
    }
    button .quit -text Quit -command {Httpd_Shutdown ; exit}
    grid .quit -columnspan 2
}
