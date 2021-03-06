# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex -direct" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded httpd 1.7 [list source [file join $dir httpd.tcl]]
package ifneeded httpd::admin 1.0 [list source [file join $dir admin.tcl]]
package ifneeded httpd::auth 2.0 [list source [file join $dir auth.tcl]]
package ifneeded httpd::cgi 1.1 [list source [file join $dir cgi.tcl]]
package ifneeded httpd::compat 3.3 [list source [file join $dir compat.tcl]]
package ifneeded httpd::config 1.0 [list source [file join $dir config.tcl]]
package ifneeded httpd::cookie 1.0 [list source [file join $dir cookie.tcl]]
package ifneeded httpd::counter 2.0 [list source [file join $dir counter.tcl]]
package ifneeded httpd::debug 1.0 [list source [file join $dir debug.tcl]]
package ifneeded httpd::digest 1.0 [list source [file join $dir digest.tcl]]
package ifneeded httpd::direct 1.1 [list source [file join $dir direct.tcl]]
package ifneeded httpd::dirlist 1.1 [list source [file join $dir dirlist.tcl]]
package ifneeded httpd::doc 1.1 [list source [file join $dir doc.tcl]]
package ifneeded httpd::doc_error 1.0 [list source [file join $dir doc_error.tcl]]
package ifneeded httpd::doctools 1.0 [list source [file join $dir doctools.tcl]]
package ifneeded httpd::fallback 1.0 [list source [file join $dir fallback.tcl]]
package ifneeded httpd::imagemap 1.0 [list source [file join $dir imagemap.tcl]]
package ifneeded httpd::include 1.0 [list source [file join $dir include.tcl]]
package ifneeded httpd::ismaptcl 1.0 [list source [file join $dir maptcl.tcl]]
package ifneeded httpd::ismaptk 1.0 [list source [file join $dir maptk.tcl]]
package ifneeded httpd::log 1.1 [list source [file join $dir log.tcl]]
package ifneeded httpd::logstd 1.0 [list source [file join $dir logstd.tcl]]
package ifneeded httpd::mail 1.0 [list source [file join $dir mail.tcl]]
package ifneeded httpd::md5hex 1.0 [list source [file join $dir md5hex.tcl]]
package ifneeded httpd::mtype 1.1 [list source [file join $dir mtype.tcl]]
package ifneeded httpd::opentrace 1.0 [list source [file join $dir open.tcl]]
package ifneeded httpd::passcheck 1.0 [list source [file join $dir passcheck.tcl]]
package ifneeded httpd::passgen 1.0 [list source [file join $dir passgen.tcl]]
package ifneeded httpd::redirect 1.0 [list source [file join $dir redirect.tcl]]
package ifneeded httpd::safecgio 1.0 [list source [file join $dir safecgio.tcl]]
package ifneeded httpd::session 1.0 [list source [file join $dir session.tcl]]
package ifneeded httpd::srvui 1.0 [list source [file join $dir srvui.tcl]]
package ifneeded httpd::status 1.0 [list source [file join $dir status.tcl]]
package ifneeded httpd::stdin 1.1 [list source [file join $dir stdin.tcl]]
package ifneeded httpd::subst 1.0 [list source [file join $dir subst.tcl]]
package ifneeded httpd::template 1.0 [list source [file join $dir template.tcl]]
package ifneeded httpd::threadmgr 1.0 [list source [file join $dir thread.tcl]]
package ifneeded httpd::upload 1.0 [list source [file join $dir upload.tcl]]
package ifneeded httpd::url 1.2 [list source [file join $dir url.tcl]]
package ifneeded httpd::utils 1.0 [list source [file join $dir utils.tcl]]
package ifneeded httpd::version 3.5 [list source [file join $dir version.tcl]]
package ifneeded tclcrypt 1.0 [list source [file join $dir tclcrypt.tcl]]
