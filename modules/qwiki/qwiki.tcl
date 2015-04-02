###
# Implements a barebone wiki in a community object
###

package require httpd::community

tao::class httpd.qwiki {
  superclass httpd.community
  
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


    set realm /html
    if { $suffix in {/ {}} } {
      set method /html
    } else {
      set parts [split [string trim $suffix /] /]
      set node [lindex $parts 0]
      if {[my <db> exists {select entryid from entry where entryid like :node}]} {
        return [list my /wiki $parts]
      }
      if {[my <db> exists {select userid from users where userid like :node}]} {
        return [list my /user $parts]
      }
      if {[my <db> exists {select groupid from groups where groupid like :node}]} {
        return [list my /group $parts]
      }
      set method /html$suffix
    }
    set qmethod {}
    set quuid {}
    foreach {name value} $result(query) {
      if { $name eq "uuid" } {
        if {[my <db> exists {select entryid from entry where entryid like :node}} {
          set real /wiki
          set quuiid $value
        }
        if {[my <db> exists {select userid from users where userid like :node}} {
          set real /user
          set quuiid $value
        }
        if {[my <db> exists {select groupid from groups where groupid like :node}} {
          set real /group
          set quuiid $value
        }
      }
      if { $name eq "method" } {
        set qmethod $value
        break
      }
    }
    if {$quuid != {}} {
      return [list my $realm [list $quuid $qmethod]]
    } else {
      if {$qmethod != {}} {
        return [list my /html/$qmethod]
      } else {
        return [list my $method]
      }
    }
  }
  
  method /user parts {
    my variable result env
    
    set uuid [lindex $parts 0]
    set method [lindex $parts 1]
    
    set props [my <db> eval {select field,value from user_property where userid=:uuid}]
    my <db> eval {select * from users where userid=:uuid} record break
    my reset
    my puts {
<html><head><title>User $record(username)</title></head><body>
    }
    my puts "<TABLE>"
    foreach {field value} [array get record] {
      my puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }    
    foreach {field value} $props {
      my puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    my <db> eval {select distinct acl_name from acl} {
      my puts "<TR><TH>Rights $acl_name</TH><Td>[my aclRights $acl_name $record(userid)]</TD></TR>"
    }
    my puts "</TABLE>"
    my puts <hr>
    my puts "<TABLE>"
    foreach {field value} [array get result] {
      if { $field in {body session session_delta} } continue
      my puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    my puts "</TABLE>"
    my puts "<hr>Session<p>"
    my puts "<TABLE>"
    foreach {field value} [get result(session)] {
      my puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    my puts "</TABLE>"
    my puts "<hr>ENV<p>"
    my puts "<TABLE>"
    foreach {field value} [array get env] {
      my puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    my puts "</TABLE>"
    my puts "</BODY></HTML>"
  }
  

  method /html/env args {
    my variable env
    
    set uuid [lindex $parts 0]
    set method [lindex $parts 1]
    
    set props [my <db> eval {select field,value from user_property where userid=:uuid}]
    my <db> eval {select * from users where userid=:uuid} record break
    my reset
    my puts "
<html><head><title>User $record(username)</title></head><body>
    "
    my puts "<TABLE>"
    foreach {field value} [array get env] {
      my puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }    
    my puts "</TABLE>"
    my puts "</BODY></HTML>"
  }
}

package provide httpd::qwiki 0.1