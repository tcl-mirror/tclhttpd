# main.tcl
#
# This script has the per-thread initialization for TclHttpd.
# The httpd.tcl startup script will call this for the main thread,
# and then (if applicable) each worker thread will source this
# file to initialize itself.

# Standard Library dependencies
package require ncgi
package require html

# Core modules
package require httpd           ;# Protocol stack
package require html            ;# Simple html generation
package require url		;# URL dispatching
package require mtype           ;# Mime types
package require counter         ;# Statistics
package require mtype           ;# Mime content types
package require utils           ;# junk
package require threadmgr	;# Thread stuff.  This is in bed with
				;# httpd and still needed if you are not
				;# using threads.
package require redirect	;# URL redirection
package require auth            ;# Basic authentication
package require log             ;# Standard loggin


# Image maps are done either using a Tk canvas (!) or pure Tcl.

if {[info exists tk_version]} {
    package require ismaptk
} else {
    package require ismaptcl
}
# These packages are required for "normal" web servers

package require doc		;# Basic file URLS
package require include		;# Server side includes
package require cgi		;# Standard CGI
package require dirlist		;# Directory listings

# These packages are for special things built right into the server

package require direct		;# Application Direct URLs
package require status		;# Built in status counters
package require mail		;# Crude email support
package require admin		;# Url-based administration
package require session		;# Session state module (better Safe-Tcl)
package require debug		;# Debug utilites

# This is currently broken
if {0} {
    package require safetcl	;# External process running safetcl shells
}

# These packages are for the SNMP demo application

if {[catch {
    package require snmp       ;# SNMP form creation
    package require Tnm        ;# Low level network stuff (Scott extension)
}]} {
    puts "No SNMP support"
}

# For information about these calls, see htdocs/reference.html

Doc_Root		$Config(docRoot)
Doc_IndexFile		index.{tml,html,shtml,thtml,htm,subst}
Doc_PublicHtml		public_html
Cgi_Directory		/cgi-bin
Mtype_ReadTypes 	[file join $Config(lib) mime.types]
Status_Url		/status /images
Debug_Url		/debug
Mail_Url		/mail
Admin_Url		/admin
Redirect_Init		/redirect
Doc_TemplateInterp	{}
Doc_CheckTemplates	1
Doc_TemplateLibrary	$Config(library)
Doc_ErrorPage		/error.html
Doc_NotFoundPage	/notfound.html
Doc_Webmaster		$Config(webmaster)
if {[catch {
    Auth_AccessFile	.htaccess       ;# Enable Basic Auth
} err]} {
    puts "No .htaccess support: $err"
}

