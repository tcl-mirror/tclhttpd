# Tcl package index file, version 1.1

# This file is handcrafted so that the multitude of related packages
# don't pollute the package namespace until you package require httpd

package ifneeded httpd 1.3 [list HttpdPackageSetup $dir]

proc HttpdPackageSetup {dir} {
    uplevel 1 [list source [file join $dir httpd.tcl]]

    package ifneeded httpd::admin 1.0 [list source [file join $dir admin.tcl]]
    package ifneeded httpd::auth 1.0 [list source [file join $dir auth.tcl]]
    package ifneeded httpd::cgi 1.0 [list source [file join $dir cgi.tcl]]
    package ifneeded httpd::config 1.0 [list source [file join $dir config.tcl]]
    package ifneeded httpd::counter 1.0 [list source [file join $dir counter.tcl]]
    package ifneeded httpd::debug 1.0 [list source [file join $dir debug.tcl]]
    package ifneeded httpd::demo 1.0 [list source [file join $dir demo.tcl]]
    package ifneeded httpd::direct 1.0 [list source [file join $dir direct.tcl]]
    package ifneeded httpd::dirlist 1.0 [list source [file join $dir dirlist.tcl]]
    package ifneeded httpd::doc 1.0 [list source [file join $dir doc.tcl]]
    package ifneeded httpd::eval 1.0 [list source [file join $dir sendsock.tcl]]
    package ifneeded httpd::include 1.0 [list source [file join $dir include.tcl]]
    package ifneeded httpd::ismaptcl 1.0 [list source [file join $dir imagemap.tcl]]\n[list source [file join $dir maptcl.tcl]]
    package ifneeded httpd::ismaptk 1.0 [list source [file join $dir maptk.tcl]]
    package ifneeded httpd::log 1.0 [list source [file join $dir log.tcl]]
    package ifneeded httpd::mail 1.0 [list source [file join $dir mail.tcl]]
    package ifneeded httpd::mtype 1.0 [list source [file join $dir mtype.tcl]]
    package ifneeded httpd::opentrace 1.0 [list source [file join $dir open.tcl]]
    package ifneeded httpd::passcheck 1.0 [list source [file join $dir passcheck.tcl]]
    package ifneeded httpd::redirect 1.0 [list source [file join $dir redirect.tcl]]
    package ifneeded httpd::safecgio 1.0 [list source [file join $dir safecgio.tcl]]
    package ifneeded httpd::session 1.0 [list source [file join $dir session.tcl]]
    package ifneeded httpd::snmp 1.0 [list source [file join $dir discover.tcl]]\n[list source [file join $dir snmp.tcl]]
    package ifneeded httpd::srvui 1.0 [list source [file join $dir srvui.tcl]]
    package ifneeded httpd::status 1.0 [list source [file join $dir status.tcl]]
    package ifneeded httpd::stdin 1.1 [list source [file join $dir stdin.tcl]]
    package ifneeded httpd::telnet 1.0 [list source [file join $dir telnet.tcl]]
    package ifneeded httpd::threadmgr 1.0 [list source [file join $dir thread.tcl]]
    package ifneeded httpd::url 1.0 [list source [file join $dir url.tcl]]
    package ifneeded httpd::utils 1.0 [list source [file join $dir utils.tcl]]
    package ifneeded httpd::version 3.1.0 [list source [file join $dir version.tcl]]
}
