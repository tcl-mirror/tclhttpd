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
package require httpd::doc_error	;# Doc_NotFound
package require httpd::url	;# Url_PrefixInstall Url_PrefixRemove Url_QuerySetup
package require httpd::utils	;# file iscommand
package require TclOO
package require tao

###
# Class that represents a web page in
# progress
###
tao::class httpd.result {
  superclass
  
  variable sock
  variable data
  variable state
  variable body
  variable cookie
  variable query
  variable session_data
  
  option cache-until {type unixtime default 0}
  option url_prefix {}
  option url_suffix {}
  option code {
    default 200
  }
  option content-type {
    default text/html
  }
  option title {}
  option redirect {}
  
  constructor {newsock prefix suffix} {
    my variable sock cgienv
    set sock $newsock
    my configurelist [list url_prefix $prefix url_suffix $suffix]

    # Set up the environment a-la CGI.
    ::Cgi_SetEnv $sock $prefix$suffix [my varname cgienv]

    # Prepare an argument data from the query data.
    my variable query
    ::Url_QuerySetup $sock
    set query [ncgi::nvlist]
  }
  
  destructor {
    
  }
  
  method sock {} {
    my variable sock
    return $sock
  }
  
  method data_get {field} {
    my variable sock
    upvar #0 Httpd$sock data
    if {![info exists data($field)]} {
      return {}
    }
    return $data(field)
  }
  
  method cgi {method args} {
    my variable cgienv
    switch $method {
      dump {
        return [array get cgienv]
      }
      get {
        set field [lindex $args 0]
        if {[info exists cgienv($field)]} {
          return $cgienv($field)
        }
        return {}
      }
      varname {
        return [my varname cgienv]
      }
      default {
        error "Valid: dump,get,varname"
      }
    }
  }

  method httpdHostName {} {
    my variable cgienv
    return [lindex [split [get cgienv(HTTP_HOST)] :] 0]
  }
  
  ###
  # Return a dict with:
  # * body
  # * content-type
  # * code (200,404,etc)
  # * cache-until (Unix datestamp when cache of this data expires, or 0)
  ###
  method httpReply {} {
    my variable body session_data
    set result {}
    dict set result content-type [my cget content-type]
    dict set result code         [my cget code]
    dict set result cache-until  [my cget cache-until]
    dict set result redirect     [my cget redirect]
    dict set result sessionid    [my cget sessionid]
    dict set result session       $session_data
    dict set result body $body

    return $result
  }
  
  method body {} {
    my variable body
    set title [my cget title]
    return [string map [list @TITLE@ $title] $body]
  }
  
  method query {} {
    my variable query
    return $query
  }
  
  method reset {} {
    my variable body
    set body {}
  }
  
  method puts args {
    my variable body
    append body {*}$args \n
  }
  
  #
  #@c	Return a *list* of cookie values, if present, else ""
  #@c	It is possible for multiple cookies with the same key
  #@c	to be present, so we return a list.
  #@c     This always gets the cookie state associated with the specified
  #@c     socket, unlike Cookie_Get that looks at the environment.
  #
  # Arguments:
  #@a	cookie	The name of the cookie (the key)
  #@a	sock	A handle on the socket connection
  # Returns:
  #@r	a list of cookie values matching argument
  method cookie_get {cookie} {
    my variable sock
    upvar #0 Httpd$sock data
    set result ""
    set rawcookie ""
    if {[info exist data(mime,cookie)]} {
        set rawcookie $data(mime,cookie)
    }
    foreach pair [split $rawcookie \;] {
        lassign [split [string trim $pair] =] key value
        if {[string compare $cookie $key] == 0} {
            lappend result $value
        }
    }
    return $result
  }
    
  #$c	make a cookie from name value pairs
  #
  # Arguments:
  #	args	Name value pairs, where the names are:
  #@a		-name	Cookie name
  #@a		-value	Cookie value
  #@a		-path	Path restriction
  #@a		-domain	domain restriction
  #@a		-expires	Time restriction
  #@a		-secure Append "secure" to cookie attributes
  #@r	a formatted cookie
  
  method cookie_make {args} {
    array set opt $args
    set line "$opt(-name)=$opt(-value) ;"
    foreach extra {path domain} {
        if {[info exist opt(-$extra)]} {
            append line " $extra=$opt(-$extra) ;"
        }
    }
    if {[info exist opt(-expires)]} {
        switch -glob -- $opt(-expires) {
            *GMT {
                set expires $opt(-expires)
            }
            default {
                set expires [clock format [clock scan $opt(-expires)] \
                        -format "%A, %d-%b-%Y %H:%M:%S GMT" -gmt 1]
            }
        }
        append line " expires=$expires ;"
    }
    if {[info exist opt(-secure)]} {
        append line " secure "
    }
    return $line
  }
  
  method cookie_set {field value {expire {}}} {
    my variable sock
    upvar #0 Httpd$sock data
    
    foreach host [my httpdHostName] {
      if { $host eq "localhost" } { set host {} }
      set cookie_args [list -name $field \
        -value $value \
        -domain $host \
        -path [my cget virtual]]
      if {[string is integer expire]} {
        lappend cookie_args -expires [clock format [expr [clock seconds] + [set expire]] -format "%Y-%m-%d"]
      }
      # Appending to the data(set-cookie) elimates the entire
      # kangaroo code that normally goes on with httpd
      lappend data(set-cookie) [my cookie_make {*}$cookie_args]
    }
  }
  
  method session {method args} {
    my variable session_data
    switch $method {
      anonymous {
        if {[dict getnull $session_data username] in {{} nobody anonymous}} {
          return 1
        }
        return 0
      }
      build {
        set session_data [::tao::args_to_options {*}$args]
      }
      dump {
        return $session_data
      }
      get {
        return [dict getnull $session_data [lindex $args 0]]
      }
      userid {
        set userid [dict getnull $session_data userid]
        if { $userid eq {} } {
          return local.anonymous
        }
        return $userid
      }
      set {
        #dict set session_data {*}args
        foreach {key value} [::tao::args_to_options {*}$args] {
          dict set session_data $key $value
        }
      }
      unset {
        dict unset session_data {*}args
      }
      varname {
        return [my varname session_data]
      }
      default {
        error "Valid: build.dump,get,set,unset,varname"
      }
    }
  }
}

###
# Create a standalone class suitable for using in a pure tcloo
# environment
###
tao::class httpd.url {
  superclass 
  aliases httpd.meta httpd.taourl
  
  property options_strict 0
  option virtual {}
  option threadargs {}
  
  #method Option_set::virtual newvalue {
  #  
  #}
  
  constructor {virtual {localopts {}} args} {
    my configurelist [list virtual $virtual threadargs $args {*}$localopts]
    ::Url_PrefixInstall $virtual [namespace code {my httpdDirect}] {*}$args
    my initialize
  }
  

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
    set prefix [my cget virtual]
    set resultObj [httpd.result new $sock $prefix $suffix]
    my httpdSessionLoad $resultObj $prefix $suffix
    set cmd [my httpdMarshalArguments $resultObj]
    # Eval the command.  Errors can be used to trigger redirects.

    if [catch $cmd] {
      ::Httpd_ReturnData $sock text/html "<HTML><BODY>Error: <PRE><VERBATIM>$::errorInfo</VERBATIM></PRE></BODY></HTML>" 505
      $resultObj destroy
      return
    }
    set result [$resultObj httpReply]
    set code [dict get $result code]
    if {[string index $code 0] in {0 2}} {
      # Normal reply
      my httpdSessionSave $result
    }
    
    switch $code {
      401 {
        ::Httpd_ReturnData $sock text/html $::HttpdAuthorizationFormat $code
      }
      404 {
        ::Doc_NotFound $sock
      }
      302 {
        # Redirect.
        ::Httpd_Redirect [dict get $result redirect] $sock
      }
      default {
        if {[dict get $result cache-until] > 0} {
          ::Httpd_ReturnCacheableData $sock [dict get $result content-type] [dict get $result body] [dict get $result cache-until] [dict get $result code]
        } else {
          ::Httpd_ReturnData $sock [dict get $result content-type] [dict get $result body] [dict get $result code]
        }
      }
    }
    $resultObj destroy

  }
  
  method httpdSessionLoad {resultObj prefix suffix} {}
  
  method httpdSessionSave result {}
  
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
  method httpdMarshalArguments resultObj {
    set prefix [$resultObj cget url_prefix]
    set suffix [$resultObj cget url_suffix]

    if { $suffix in {/ {}} } {
      set method /html
    } else {
      set method /html$suffix
    }
    foreach {name value} [$resultObj query] {
      if { $name eq "method" } {
        set method /html/$value
        break
      }
    }
    return [list my $method $resultObj]
  }
  
  method unknown {args} {
    if {[string range [lindex $args 0] 0 4] eq "/html"} {
      my HtmlNotFound {*}$args
      return
    }
    next {*}$args
  }
  
  ###
  # title: Implement html content at a toplevel
  ###
  method /html resultObj {
    $resultObj reset
    $resultObj configure title {Welcome!}
    $resultObj puts [my pageHeader]
    $resultObj puts {
Hello World
    }
    $resultObj puts [my pageFooter]
  }
  
  method HtmlNotFound args {
    set resultObj [lindex $args 0]
    $resultObj configure code 404
    $resultObj configure title {Page Not Found}
  }
  
  method pageHeader {} {
    return {
<HTML>
<HEAD>
    <TITLE>@TITLE@</TITLE>
    <link rel="stylesheet" href="/bootstrap/css/bootstrap.min.css">
</HEAD>
<BODY>
    }
  }
  
  method pageFooter {} {
    return {
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/jquery.min.js"></script>
</BODY></HTML>
    }
  }

}
