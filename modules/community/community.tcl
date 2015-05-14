###
# Facilities for user, group, and community management
###
package require tao
package require sqlite3
package require tao-sqlite
package require md5 2
package require sha1 2

package require httpd::directoo
package require httpd::cookie	;# Cookie_GetSock Cookie_Make
package require httpd::doc	;# Doc_Root
package require httpd::utils	;# Stderr file iscommand randomx
package require httpd::jshash   ;# Javascript password hashes
package require httpd::bootstrap
package require cron

tao::class community.layer {
  superclass httpd.url tao::layer taodb::table

  ###
  # Code to produce the schema in sql
  ###
  property schema create_sql {}
  property schema version 0.1
  property module {}
  
  constructor {sharedobjects threadargs args} {
    foreach {organ object} $sharedobjects {
      my graft $organ $object
    }
    my graft layer [self]
    my configurelist [::tao::args_to_options {*}$args]
    ::Url_PrefixInstall [my cget virtual] [namespace code {my httpdDirect}] {*}$threadargs
  }
  
  destructor {
    catch {::Url_PrefixRemove [my cget virtual]}
  }
  
  method schema_check {} {
    set module [my property module]
    set version [my property schema version]
    ###
    # Create our schema if it doesn't exist
    ###
    if {![my <db> exists {select version from module where name=:module}]} {
      my <db> eval [my property schema create_sql]
      my <db> eval {insert or replace into module(name,version) VALUES (:module,:version)}
      # Send a signal to child classes calling us through [next]
      return 1
    }
    ###
    # From here on out, swap out components to incrementally update
    # the schema
    ###
    return 0
  }
  
  method initialize {} {
    my schema_check
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
  method httpdMarshalArguments resultObj {
    set prefix [$resultObj cget url_prefix]
    set suffix [$resultObj cget url_suffix]
    set uuid {}
    if { $suffix in {/ {}} } {
      set method /html
    } else {
      set parts [split [string trim $suffix /] /]
      set uuid [lindex $parts 0]
      set method /html/[join [lrange $parts 1 end] /]
    }
    set pkey  [my property schema primary_key]
    foreach {name value} [$resultObj query] {
      if { $name in [list uuid $pkey]} {
        set uuid $value
      }
      if { $name eq "method" } {
        set method /html/$value
        break
      }
    }
    if {$uuid ne {}} {
      resultObj configure uuid $uuid
    }
    return [list my $method $resultObj]
  }
  
  ###
  # topic: 88c79c0e9188a477f535b66b01631961
  ###
  method node_is_managed unit {
    set prefix [my cget prefix]
    if { $unit eq $prefix } {
      return 1
    }
    set table [my property schema table]
    set pkey  [my property schema primary_key]
    return [my <db> exists "select $pkey from $table where $pkey=:unit"]
  }
  
  ###
  # Return a command if this object hijacks a method
  # from the community
  ###
  method url_is_managed resultObj {
   return {}
  }
  
  method task_hourly {} {}
  method task_daily {} {}
  
  method /html resultObj {
    $resultObj puts [my <community> pageHeader]
    $resultObj puts "Node: [$resultObj cget uuid]
    $resultObj puts [my <community> pageFooter]
  }
}

tao::class community.layer.user {
  superclass community.layer

  property module user
  property schema version 1.0  
  property schema table users
  property schema primary_key userid
  property schema create_sql {
    CREATE TABLE if not exists users (
      userid string default (uuid_generate()),
      username  STRING,
      password  STRING,
      name  STRING,
      email  STRING,
      type  STRING,
      primary key (userid)
    );
    CREATE UNIQUE INDEX if not exists username  on users (username);
    
    create table if not exists user_property (
      userid    string references users (userid) ON UPDATE CASCADE ON DELETE CASCADE,
      field      string,
      value      string,
      primary key (userid,field)
    );
insert into users(userid,username,password) VALUES ('local.webmaster','webmaster',sha1((select value from config where name='community-id')||'password'));
insert into users(userid,username,password) VALUES ('local.anonymous','anonymous','');  
  }
  
  method /html resultObj {    
    set uuid [$resultObj cget uuid]
    set method [lindex $parts 1]
    
    set props [my <db> eval {select field,value from user_property where userid=:uuid}]
    my <db> eval {select * from users where userid=:uuid} record break
    $resultObj configure title "User $record(username)"
    $resultObj puts [my <community> pageHeader]    
    $resultObj puts "<TABLE>"
    foreach {field value} [array get record] {
      $resultObj puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }    
    foreach {field value} $props {
      $resultObj puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    my <db> eval {select distinct acl_name from acl} {
      $resultObj puts "<TR><TH>Rights $acl_name</TH><Td>[my aclRights $acl_name $record(userid)]</TD></TR>"
    }
    $resultObj puts "</TABLE>"
    $resultObj puts <hr>
    $resultObj puts "<hr>Session<p>"
    $resultObj puts "<TABLE>"
    foreach {field value} [$resultObj session dump] {
      $resultObj puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    $resultObj puts "</TABLE>"
    $resultObj puts "<hr>ENV<p>"
    $resultObj puts "<TABLE>"
    foreach {field value} [$resultObj cgi dump] {
      $resultObj puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }
    $resultObj puts "</TABLE>"
    $resultObj puts [my <community> pageFooter]    

  }
  

}

tao::class community.layer.group {
 superclass community.layer

  property module group
  property schema version 1.0  
  property schema table groups
  property schema primary_key groupid
  property schema create_sql {
    CREATE TABLE if not exists groups (
      groupid string default (uuid_generate()),
      groupname STRING,
      acl_name  string references acl (acl_name) ON UPDATE CASCADE ON DELETE SET NULL,
      primary key (groupid)
    );
    CREATE TABLE if not exists group_members (
      groupid string references groups (groupid) ON UPDATE CASCADE ON DELETE CASCADE,
      userid string references users (userid) ON UPDATE CASCADE ON DELETE CASCADE
    );
    create table if not exists group_property (
      groupid    string references groups (groupid) ON UPDATE CASCADE ON DELETE CASCADE,
      field      string,
      value      string,
      primary key (groupid,field)
    );
insert into groups(groupid,groupname) VALUES ('local.wheel','wheel');
insert into group_members(userid,groupid) VALUES ('local.webmaster','local.wheel');
  }
}

tao::class community.layer.session {
  superclass community.layer
  property module session

  property module session
  property schema version 1.0  
  property schema table session
  property schema primary_key sesid
  
  property schema create_sql {
    CREATE TABLE session (
      sesid string default (uuid_generate()),
      userid string references users (userid) ON UPDATE CASCADE ON DELETE CASCADE,
      expires   int,
      primary key (sesid)
    );
    
    create table if not exists session_property (
      sesid    string references session (sesid) ON UPDATE CASCADE ON DELETE CASCADE,
      field      string,
      value      string,
      primary key (sesid,field)
    );
  }
  
  method task_hourly {} {
    set now [clock seconds]
    my <db> eval {delete from session where expires<:now;}
  }
}

tao::class community.layer.acl {
  superclass community.layer
  property module acl

  property module acl
  property schema version 1.0  
  property schema table acl
  property schema primary_key acl_name
  
  property schema create_sql {
    CREATE TABLE acl (
    parent   string references acl (acl_name) ON UPDATE CASCADE ON DELETE SET NULL,
    acl_name text not null,
    primary key (acl_name)
    );
    CREATE TABLE acl_grants (
    acl_name  string references acl (acl_name) ON UPDATE CASCADE ON DELETE SET NULL,
    userid    string references users (userid) ON UPDATE CASCADE ON DELETE SET NULL,
    grant     int default 1,
    right     text,
    UNIQUE (acl_name,userid,right)
    );
    
insert into acl (acl_name) VALUES ('admin');
insert into acl_grants (acl_name,userid,grant,right) VALUES ('admin','local.wheel',1,'all');

insert into acl (acl_name) VALUES ('default');
insert into acl_grants (acl_name,userid,grant,right) VALUES ('default',NULL,1,'view');
  }
}

tao::class httpd.community {  
  superclass httpd.url taodb::connection.sqlite
  
  option virtual {}
  option community-id {}

  ###
  # This class extents the yggdrasil schema to
  # include session management, user management,
  # and access control lists
  ###
  property schema create_sql {
    CREATE TABLE if not exists config(
      name TEXT PRIMARY KEY,
      value ANY
    );
    CREATE TABLE if not exists module(
      name TEXT PRIMARY KEY,
      version ANY
    );
--- POPULATE WITH DATA ---
insert into config(name,value) VALUES ('community-id',uuid_generate());
  }
  
  destructor {
    next
    cron::cancel [self].session_flush
    cron::cancel [self].backup_db
  }
  
  method Shared_Organs {} {
    set shared {}
    dict set shared db [my organ db]
    dict set shared community [self]
    return $shared
  }
  
  method active_layers {} {
    return {
      user    {prefix uid class community.layer.user}
      group   {prefix gid class community.layer.group}
      session {prefix sesid class community.layer.session}
      acl     {prefix acl class community.layer.acl}
    }
  }

  ###
  # topic: 81232b0943dce1f2586e0ac6159b1e2e
  ###
  method activate_layers {{force 0}} {
    set self [self]
    my variable layers
    set result {}
    set active [my active_layers]

    ###
    # Destroy any layers we are not using
    ###
    set lbefore [get layers]
    foreach {lname obj} $lbefore {
      if {![dict exists $active $lname] || $force} {
        $obj destroy
        dict unset layers $lname
      }
    }

    ###
    # Create or Morph the objects to represent
    # the layers, and then stitch them into
    # the application, and the application to
    # the layers
    ###
    set shared [my Shared_Organs]
    set root [my cget virtual]
    set threadargs [my cget threadargs]
    foreach {lname info} $active {
      set created 0
      set prefix [dict get $info prefix]
      set class  [dict get $info class]
      set layer_obj [my SubObject layer $lname]
      dict set layers $lname $layer_obj
      if {[info command $layer_obj] == {} } {
        $class create $layer_obj $shared $threadargs virtual $root/$prefix prefix $prefix layer_name $lname threadargs $threadargs
        set created 1
        foreach {organ object} $shared {
          $layer_obj graft $organ $object
        }
      } else {
        foreach {organ object} $shared {
          $layer_obj graft $organ $object
        }
        $layer_obj morph $class
      }
      ::ladd result $layer_obj
      $layer_obj event subscribe [self] *
      $layer_obj initialize
    }
    my action activate_layers
    return $result
  }

  method initialize {} {
    if {[my cget filename] eq {}} {
      my configure filename :memory:
    }
    my Database_Attach [my cget filename]
    my configurelist [my <db> eval {select name,value from config}]
    if {[my cget community-id] eq {}} {
      my configure community-id [::tao::uuid_generate]
    }
    my activate_layers
    ###
    # Clean up expired sessions
    ### 
    cron::every [self].hourly [expr {3600}] [namespace code {my task_hourly}]
    
    ###
    # Back up the database every day
    ###
    cron::every [self].daily [expr {3600*24}] [namespace code {my task_daily}]
  }

  method task_hourly {} {
    my variable layers
    foreach {name obj} $layers {
      $obj task_hourly
    }
  }
  
  method task_daily {} {
    my variable layers
    my Database_Backup
    foreach {name obj} $layers {
      $obj task_hourly
    }
  }
  
  method Database_Create {} {
    my <db> eval [my schema create_sql]
  }
  
  method ClockFormat {time {format {}}} {
    if { $format eq {} } {
      return [clock format $time]
    }
    return [clock format $time -format $format]
  }
  
  method ClockScan {time {format {}}} {
    if { $format eq {} } {
      return [clock format $time]
    }
    return [clock scan $time -format $format]
  }

  method Database_Functions {} {
    set seed [info hostname]
    my <db> function uuid_generate ::tao::uuid_generate
    my <db> function sha1    {::sha1::sha1 -hex}
    my <db> function now   {clock seconds}
    my <db> function clock_format [namespace code {my ClockFormat}]
    my <db> function clock_scan   [namespace code {my ClockScan}]

  }

  method aclAccessTypes {} {
    set aclAccessTypes {admin edit view}
    foreach type [my <db> eval "select distinct right from acl_grants order by right"] {
        logicset add aclAccessTypes $type
    }     
    return $aclAccessTypes    
  }

  method aclRights {aclname userid} {
    set parentlist {}
    set thisnode $aclname
    
    while 1 {
      set parentlist [linsert $parentlist 0 $thisnode]
      set parent [my one "select parent from acl where acl_name=:thisnode"]
      if { $parent == {} } { 
          break
      }
      # Something is mislinked, stop early
      if {$parent in $parentlist} break
      set thisnode $parent
    }
  
    ###
    #  Build grouplist
    ###
    set rights {}
    ###
    # Apply default rights
    ###
    foreach {right grant} [my <db> eval "select right,grant from acl_grants where acl_name='default'"] {
      if { $grant == "0"} {
          if { $right == "all" } { 
              set rights {}
          } else {
              logicset remove rights $right
          }
      } else {
        if { $right eq "all" } {
          logicset add rights {*}[my aclAccessTypes]
        } else {
          logicset add rights $right
        }
      }
    }
    
    foreach p $parentlist {
        set stmt "select right,grant from acl_grants where \
  acl_name=:p and userid=:userid or userid=(select username from users where userid=:userid) or userid in (select groupid from group_members where userid=:userid);
  "
      foreach {right grant} [my <db> eval $stmt] {
        if { $grant == "0"} {
            if { $right == "all" } { 
                set rights {}
            } else {
                logicset remove rights $right
            }
        } else {
          if { $right eq "all" } {
            logicset add rights {*}[my aclAccessTypes]
          } else {
            logicset add rights $right
          }
        }
      }
    }
    return $rights
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
  method httpdMarshalArguments resultObj {
    my variable layers
    ###
    # Try to pass the page off to one of my layers
    ###
    foreach {lname layer} $layers {
      if {[set cmd [$layer url_is_managed $resultObj]] ne {}} {
        return $cmd
      }
    }
    ###
    # Otherwise look for a local method
    ###
    return [next $resultObj]
  }
  
  method httpdSessionLoad {resultObj prefix suffix} {
    set found 0
    set sessionid {}
    set userid    {}
    
    ###
    # Look for a session id in the query
    ###
    foreach {field value} [$resultObj query] {
      if {$field eq "sessionid"} {
        set stmt {select userid from session where sesid=:value}
        if {[my <db> exists $stmt]} {
          set userid [my <db> one $stmt]
          set sessionid $value
          break
        }
      }
    }
    if {$sessionid eq {}} {
      ###
      # Look for a sessionid in cookies
      ###
      foreach {value} [$resultObj cookie_get sessionid] {
        set stmt {select userid from session where sesid=:value}
        if {[my <db> exists $stmt]} {
          set userid [my <db> one $stmt]
          set sessionid $value
          break
        }
      }
    }
    if {![my <db> exists {select username from users where userid=:userid}]} {
      set userid local.anonymous
      set username anonymous
      set anonymous 1
    } else {
      set username [my <db> one {select username from users where userid=:userid}]
      if { $userid == "local.anonymous" } {
        set anonymous 1
      } else {
        set anonymous 0
      }
    }
    if {$sessionid eq {}} {
      set sessionid [::tao::uuid_generate]
      my <db> eval {
insert into session(sesid,userid) VALUES (:sessionid,:userid);
      }
    }

    $resultObj configure \
      sessionid $sessionid \
      userid $userid \
      username $username
    
    set session [my <db> eval {select field,value from session_property where sesid=:sessionid}]
    dict set session userid $userid
    dict set session username $username
    dict set session anonymous $anonymous
    $resultObj session build $session

    # Save any return cookies which have been set.
    # This works with the Doc_SetCookie procedure that populates
    # the global cookie array.

    set expdate  [expr {14*86400}]
    set expires  [expr {[clock seconds]+$expdate}]
    my <db> eval {update session set expires=:expires where sesid=:sesid;}
    $resultObj cookie_set sessionid $sessionid $expdate
  }
    
  method httpdSessionSave result {
    dict unset result body

    set sesid   [dict get $result sessionid]
    set session [dict get $result session]
    set session_delta [my <db> eval {select field,value from session_property where sesid=:sesid}]
    set add {}
    set delete {}
    set modify {}

    foreach {field value} $session {
      if {![dict exists $session_delta $field]} {
        lappend add $field $value
      } elseif {$value != [dict get $session_delta $field]} {
        lappend modify $field $value
      }
    }
    foreach {field value} $session_delta {
      if {![dict exists $session $field]} {
        lappend delete $field $value
      }
    }

    if {[llength $add]||[llength $delete]||[llength $modify]} {
      my db eval "BEGIN TRANSACTION"
      foreach {field value} $add {
        my <db> eval {insert or replace into session_property(sesid,field,value) VALUES (:sessionid,:field,:value);}
      }
      foreach {field value} $modify {
        my <db> eval {update session_property set value=:value where sesid=:sessionid and field=:field;}
      }
      foreach {field value} $delete {
        my <db> eval {delete from session_property where sesid=:sessionid and field=:field;}
      }
      my <db> eval "COMMIT"
    }
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

  method /html/logout resultObj {
    set sesid [$resultObj cget sessionid]
    my <db> eval {
update session set userid='local.anonymous' where sesid=:sesid;
delete from session_property where sesid=:sesid;
}
    $resultObj session build username anonymous userid local.anonymous anonymous 1
    $resultObj configure login-message {You have been logged out}
    my /html/login $resultObj
  }
  
  method /html/login resultObj {
    set sessionid [$resultObj cget sessionid]
    $resultObj reset
    $resultObj puts <html>
    $resultObj puts {
  <head>
    <link rel="stylesheet" href="/bootstrap/css/bootstrap.min.css">
    <script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
    <script type="text/javascript" src="/bootstrap/js/jquery.min.js"></script>
    <TITLE>Log In</TITLE>
    <script type="text/javascript" src="/jshash/sha1-min.js"></script>
    <script type="text/javascript">  
function login() {
  
    var p = hex_sha1(document.getElementById('key').value+document.getElementById('pass').value);  
    var k = document.getElementById('sesid').value;  

    var h = hex_sha1(k+p);  
    var hash = document.getElementById('hash');  
    hash.value = h;
    var f = document.getElementById('finalform');  
    f.submit();  
}  
    </script>
  </head>
    }    
    $resultObj puts {
  <body>
    }
    set msg [$resultObj cget login-message]
    if { $msg ne {} } {
      $resultObj puts "<pre><font color=ÓredÓ face=Ósans-serifÓ size=Ó1Ó>$msg</font></pre><hr>"
    }
    $resultObj puts {
<table>
<form action="authenticate" method="post" id="finalform">
<tr><th>Username:</th><td><input name="uid" id="uid" /></td></tr>
<input type="hidden" name="hash" id="hash" />  
</form>
    }
    $resultObj puts {<form action="javascript:login()" method="post" >}
    $resultObj puts "<input type=\"hidden\" id=\"key\" value=\"[my cget community-id]\" />"  
    $resultObj puts "<input type=\"hidden\" id=\"sesid\" value=\"$sessionid\" />"  
    $resultObj puts {
<tr><th>Password:</th><td><input type="password" id="pass" /></td></tr>
<tr><th>&nbsp</th></th><td><input type="submit" value="Log In" /></td></tr>
</table>
    </form>  

  </body>
    }
    $resultObj puts </html>
  }

  method /html/authenticate resultObj {
    set sessionid [$resultObj cget sessionid]
    foreach {field value} [$resultObj query] {
      if {$field eq "uid"} {
        set username $value
        foreach {field value} [$resultObj query] {
          if {$field eq "hash"} {
            set passhash [my <db> one {select password from users where username=:username}]
            set realhash [::sha1::sha1 -hex "$sessionid$passhash"]
            if { $realhash eq $value } {
              set userid [my <db> one {select userid from users where username=:username}]
              my <db> eval {
update session set userid=:userid where sesid=:sessionid;
}
              $resultObj session set username $username
              $resultObj session set userid $userid
              set root [my cget virtual]
              $resultObj puts "<HTML><HEAD><META HTTP-EQUIV=\"Refresh\" CONTENT=\"1; URL=$root\"></HEAD>"
              $resultObj puts {
<BODY>
You are now being logged in. You will be redirected in a moment.
<p>
              }
              $resultObj puts "<A href=\$root\>Home...</a>"
              $resultObj puts </BODY></HTML>
              return
            }
          }
        }
      }
    }
    $resultObj configure login-message {Password or Username was incorrect or invalid.}
    my /html/login $resultObj
  }
  
  method /html/env resultObj {
    if {[$resultObj session anonymous]} {
      $resultObj configure code 401
      return
    }
    $resultObj puts [my pageHeader]
    $resultObj puts "<TABLE>"
    foreach {field value} [$resultObj cgi dump] {
      $resultObj puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }    
    $resultObj puts "</TABLE>"
    $resultObj puts [my pageFooter]
  }

  method /html/session resultObj {
    if {[$resultObj session anonymous]} {
      $resultObj configure code 401
      return
    }
    $resultObj puts [my pageHeader]
    $resultObj puts "<TABLE>"
    foreach {field value} [$resultObj session dump] {
      $resultObj puts "<TR><TH>$field</TH><TD>$value</TD></TR>"
    }    
    $resultObj puts "</TABLE>"
    $resultObj puts [my pageFooter]
  }
}

package provide httpd::community 0.1
