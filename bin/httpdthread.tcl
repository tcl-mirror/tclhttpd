# httpdthread.tcl
#
# This script has the per-thread initialization for TclHttpd.
# The httpd.tcl startup script will call this for the main thread,
# and then (if applicable) each worker thread will source this
# file to initialize itself.

# Note about per-thread vs. per-application.  Essentially all
# the "package require" commands are needed in all the threads,
# while it might be possible to limit the various initialization
# calls to only the main thread.  However, it isn't easy to tell,
# so we initialize all threads to ensure that configuration state
# both affects the URL dispatch done by the main thread, and is
# visible to the worker threads.

# Standard Library dependencies
package require ncgi
package require html

# Core modules
package require httpd           ;# Protocol stack
package require url		;# URL dispatching
package require mtype           ;# Mime types
Mtype_ReadTypes 		[file join $Config(lib) mime.types]
package require counter         ;# Statistics
package require utils           ;# junk

package require redirect	;# URL redirection
package require auth            ;# Basic authentication
package require log             ;# Standard logging

if {$Config(threads) > 0} {
    package require Thread		;# C extension
    package require threadmgr		;# Tcl layer on top
}

# Image maps are done either using a Tk canvas (!) or pure Tcl.

if {[info exists tk_version]} {
    package require ismaptk
} else {
    package require ismaptcl
}
# These packages are required for "normal" web servers

# doc
# provides access to files on the local file systems.

package require doc

# Doc_Root defines the top-level directory, or folder, for
# your web-visible file structure.

Doc_Root			$Config(docRoot)

# Merge in a second file system into the URL tree.

set htdocs_2 [file join [file dirname [info script]] ../htdocs_2]
if {[file isdirectory $htdocs_2]} {
    Doc_AddRoot /addroot	$htdocs_2
}

# Doc_TemplateInterp determines which interpreter to use when
# interpreting templates.

Doc_TemplateInterp		{}

# Doc_IndexFile defines the name of the default index file
# in each directory.  Its value is a glob pattern.

Doc_IndexFile			index.{tml,html,shtml,thtml,htm,subst}

# Doc_PublicHtml turns on the mapping from ~user to the
# specified directory under their home directory.

Doc_PublicHtml			public_html

# Doc_CheckTemplates causes the processing of text/html files to
# first look aside at the corresponding .tml file and check if it is
# up-to-date.  If the .tml (or its dependent files) are newer than
# the HTML file, the HTML file is regenerated from the template.

Doc_CheckTemplates		1

# This simply adds the library to your auto_path so it can be
# accessible to the scripts run by the template pages.

Doc_TemplateLibrary		$Config(library)

# Doc_ErrorPage registers a template to be used when a page raises an
# uncaught Tcl error.  This is a crude template that is simply passed through
# subst at the global level.  In particular,  it does not have the
# full semantics of a .tml template.

Doc_ErrorPage			/error.html

# Doc_NotFoundPage registers a template to be used when a 404 not found
# error occurs.  Like Doc_ErrorPage, this page is simply subst'ed.

Doc_NotFoundPage		/notfound.html

# Doc_Webmaster returns the value last passed into it.
# Designed to be used in page templates where contact email is needed.

Doc_Webmaster			$Config(webmaster)

package require dirlist		;# Directory listings
package require include		;# Server side includes

package require cgi		;# Standard CGI
Cgi_Directory			/cgi-bin

package require direct		;# Application Direct URLs

package require status		;# Built in status counters
Status_Url			/status /images

package require mail		;# Crude email form handlers
Mail_Url			/mail

package require admin		;# Url-based administration
Admin_Url			/admin

package require session		;# Session state module (better Safe-Tcl)

package require debug		;# Debug utilites
Debug_Url			/debug

package require redirect	;# Url redirection tables
Redirect_Init			/redirect

if {[catch {
    Auth_AccessFile	.htaccess       ;# Enable Basic Auth
} err]} {
    puts "No .htaccess support: $err"
}

# This is currently broken
if {0} {
    package require safetcl	;# External process running safetcl shells
}

if {[catch {
    # These packages are for the SNMP demo application
    # "snmp" is a poorly-named module that generates HTML forms to view
    #	MIB info
    # "Tnm" is the SNMP interface from the Scotty extension

    package require snmp
    package require Tnm
    Stderr "SNMP Enabled"
}]} {
}

