###
# This package adds support for direct URLs implemented by
# TclOO Objects. They need a little extra massaging as an
# object may have its own rules about which method is being
# exercised
#
# Derived from direct.tcl
###

package provide httpd::directoo 0.1

package require httpd	;# Httpd_Redirect Httpd_ReturnData
package require httpd::cgi	;# Cgi_SetEnv
package require httpd::cookie	;# Cookie_Save
package require httpd::doc_error	;# Doc_NotFound
package require httpd::url	;# Url_PrefixInstall Url_PrefixRemove Url_QuerySetup
package require httpd::utils	;# file iscommand
package require TclOO

###
# Seperate out the working bits so that Tao and TclOO can share
# the same core functions
###
oo::class create httpd.meta {
  
  destructor {
    catch {::Url_PrefixRemove [my cget virtual]}
  }
  
  method initialize {} {}


  # This calls out to the Tcl procedure named "$prefix$suffix",
  # with arguments taken from the form parameters.
  # Example:
  # httpdDirect /device Device
  # if the URL is /device/a/b/c, then the Tcl command to handle it
  # should be
  # [self] /html/Device/a/b/c
  # You can define the content type for the results of your procedure by
  # defining a global variable with the same name as the procedure:
  # set Device/a/b/c text/plain
  #  The default type is text/html
  #
  #	This function returns the result of evaluating the direct
  #	url.  Usually, this involves returning a page, but a redirect
  #	could also occur.
  #
  # Arguments:
  # 	sock	The socket back to the client.
  #	code	The return code from evaluating the direct url.
  #	result	The return string from evaluating the direct url.
  #	type	The mime type to use for the result.  (Defaults to text/html).
  #	
  #
  # Results:
  #	None.
  #
  # Side effects:
  #	If code 302 (redirect) is passed, calls Httpd_Redirect to 
  #	redirect the current request to the url in result.
  #	If code 0 is passed, the result is returned to the client.
  #	If any other code is passed, an exception is raised, which
  #	will cause a stack trace to be returned to the client.
  #


  method httpdDirect {sock suffix} {
    global env
    upvar #0 Httpd$sock data
    my variable result
    set prefix [my cget virtual]
    my httpdSessionLoad $sock $prefix $suffix
    set cmd [my httpdMarshalArguments $sock $suffix]
    ::Stderr $cmd
    # Eval the command.  Errors can be used to trigger redirects.

    if [catch $cmd] {
      set result(code) 505
      set result(body) "<HTML><BODY>Error: <PRE><VERBATIM>$::errorInfo</VERBATIM></PRE></BODY></HTML>"
      set result(content-type) text/html 
    }
    if {[string index $result(code) 0] in {0 2}} {
      # Normal reply
      my httpdSessionSave $sock
    }
    switch $result(code) {
      401 {
        ::Httpd_ReturnData $sock text/html $::HttpdAuthorizationFormat $result(code)
        return
      }
      404 {
        ::Doc_NotFound $sock
        return
      }
      302 {
        # Redirect.
        ::Httpd_Redirect $result $sock
        return
      }
      default {
        if {$result(date)} {
          ::Httpd_ReturnCacheableData $sock $result(content-type) $result(body) $result(date) $result(code)
        } else {
          ::Httpd_ReturnData $sock $result(content-type) $result(body) $result(code)
        }
        return
      }
    }
  }
  
  method httpdSessionLoad {sock prefix suffix} {
    my variable result
    array set result {
      code 200
      date  0
      header {}
      footer {}
      body {}
      content-type text/html
    }
    set result(sock) $sock
    set result(datavar) ::Httpd$sock 

    # Set up the environment a-la CGI.
    ::Cgi_SetEnv $sock $prefix$suffix [my varname env]
    # Prepare an argument data from the query data.
    ::Url_QuerySetup $sock
    set result(query) [ncgi::nvlist]
  }
  
  method httpdSessionSave sock {
    # Save any return cookies which have been set.
    # This works with the Doc_SetCookie procedure that populates
    # the global cookie array.
    ::Cookie_Save $sock 
  }
  
  #
  #	Use the url prefix, suffix, and cgi values (set with the
  #	ncgi package) to create a Tcl command line to invoke.
  #
  # Arguments:
  #	suffix		The part of the url after the domain prefix.
  #
  # Results:
  #	Returns a Tcl command line.
  #
  # Side effects:
  #	If the suffix (and query args) do not map to a Tcl procedure,
  #	returns empty string.
  method httpdMarshalArguments {sock suffix} {
    my variable result
    set prefix [my cget virtual]

    if { $suffix in {/ {}} } {
      set method /html
    } else {
      set method /html$suffix
    }
    foreach {name value} $result(query) {
      if { $name eq "method" } {
        set method /html/$value
        break
      }
    }
    return [list my $method]
  }
  
  method reset {} {
    my variable result
    set result(body) {}
  }
  
  method puts args {
    my variable result
    append result(body) {*}$args \n
  }
  
  method unknown {args} {
    if {[string range [lindex $args 0] 0 4] ne "/html"} {
      next {*}$args
    }
    my variable result
    set result(code) 404
  }
}


###
# Create a standalone class suitable for using in a pure tcloo
# environment
###
oo::class create httpd.url {
  superclass httpd.meta
  
  variable virtual
  variable config
  
  constructor {virtual {localopts {}} args} {
    my configurelist [list virtual $virtual {*}$localopts]
    ::Url_PrefixInstall $virtual [namespace code {my httpdDirect}] {*}$args
    my initialize
  }
  
  method configurelist localopts {
    my variable config
    foreach {field value} $localopts {
      dict set config $field $value
    }
  }
  
  method cget field {
    my variable config
    if {[dict exists $config $field]} {
      return [dict get $config $field]
    }
    return {}
  }
  
  ###
  # title: Implement html content at a toplevel
  ###
  method /html {} {
    my variable result
    array set result {
      code 200
      body {
<HTML><BODY>
Hello World
</BODY></HTML>
}
      content-type text/html
    }
  }
}
