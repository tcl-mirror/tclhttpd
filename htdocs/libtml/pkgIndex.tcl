# Tcl package index file, version 1.0
# This file is generated by the "pkg_mkIndex2" command for immediate package
# loading when a package is required. It is sourced either when an application
# starts up or by a "package unknown" script.  It invokes the 
# "package ifneeded" command to set up package-related information so that
# packages will be loaded automatically in response to "package require" 
# commands. When this script is sourced, the variable $dir must contain 
# the full path name of this file's directory.
package ifneeded faq 1.2 [list source [file join $dir faq.tcl]]
package ifneeded sunscript 1.2 [list source [file join $dir sunscript.tcl]]
package ifneeded template 1.2 [list source [file join $dir template.tcl]]