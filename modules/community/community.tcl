###
# Facilities for user, group, and community management
###
package require httpd::directoo
package require sqlite3
package require tao
package require tao-sqlite
package require md5 2
package require sha1 2

package require httpd::cookie	;# Cookie_GetSock Cookie_Make
package require httpd::doc	;# Doc_Root
package require httpd::utils	;# Stderr file iscommand randomx

tao::class httpd.taourl {
  superclass httpd.meta

  property options_strict 0

  constructor {virtual {localopts {}} args} {
    my configurelist [list virtual $virtual {*}$localopts]
    ::Url_PrefixInstall $virtual [namespace code {my httpdDirect}] {*}$args
    my initialize
  }
}

tao::class httpd.community {  
  superclass httpd.taourl taodb::yggdrasil
  
  option virtual {}
  option dbfile {}

  method initialize {} {
    if {[my cget dbfile] eq {}} {
      my configure dbfile :memory:
    }
    my Database_Attach [my cget dbfile]
  }

  ###
  # This class extents the yggdrasil schema to
  # include session management, user management,
  # and access control lists
  ###
  property create_sql {
    CREATE TABLE if not exists config(
      name TEXT PRIMARY KEY,
      value ANY
    );
    create table if not exists entry (
      entryid string default (uuid_generate()),
      indexed integer default 0,
      parent integer references entry (entryid) ON UPDATE CASCADE ON DELETE SET NULL,
      acl_name  string references acl (acl_name) ON UPDATE CASCADE ON DELETE SET NULL,
      class string,
      name string,
      mtime integer,
      primary key (entryid)
    );

    create table if not exists property (
      entryid    string references entry (entryid) ON UPDATE CASCADE ON DELETE CASCADE,
      field      string,
      value      string,
      primary key (entryid,field)
    );

    create table if not exists link (
      linktype string,
      entry integer references entry (entryid) ON UPDATE CASCADE ON DELETE CASCADE,
      refentry integer references entry (entryid)  ON UPDATE CASCADE ON DELETE CASCADE
    );

    create table if not exists idset (
      class string,
      id    integer,
      name  string,
      primary key (class,id)
    );
    create table if not exists aliases (
      class string,
      alias string,
      cname string references entry (name),
      primary key (class,alias)
    );
    create table if not exists repository (
      handle string,
      localpath string,
      primary key (handle)
    );
    create table if not exists file (
      fileid         string default (uuid_generate()),
      repo           string references repository (handle) ON UPDATE CASCADE ON DELETE CASCADE,
      path           string,  --path relative to repo
      localpath      string,  --cached path to local file
      filename       string,  --filename
      content_type   string,  --Content/Type of file
      package        string,  --Name of any packages provided,
      size           integer, --File size in bytes
      mtime          integer, --mtime in unix time
      hash           string,   --sha1 hash of file
      replaces       string references file (fileid) ON UPDATE CASCADE ON DELETE SET NULL,
      primary key (fileid)
    );
    create table if not exists filelink (
      linktype string,
      entryid integer references entry (entryid)  ON UPDATE CASCADE ON DELETE CASCADE,
      fileid integer references file   (fileid)  ON UPDATE CASCADE ON DELETE CASCADE
    );
    
    --BEGIN COMMUNITY EXTENSIONS--
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

--- POPULATE WITH DATA ---
insert into users(userid,username,password) VALUES ('local.webmaster','webmaster',sha1('local.webmaster'||'password'));
insert into users(userid,username,password) VALUES ('local.anonymous','anonymous','');

insert into groups(groupid,groupname) VALUES ('local.wheel','wheel');
insert into group_members(userid,groupid) VALUES ('local.webmaster','local.wheel');

insert into acl (acl_name) VALUES ('admin');
insert into acl_grants (acl_name,userid,grant,right) VALUES ('admin','local.wheel',1,'all');

insert into acl (acl_name) VALUES ('default');
insert into acl_grants (acl_name,userid,grant,right) VALUES ('default',NULL,1,'view');

  }

  method Database_Functions {} {
    set seed [info hostname]
    my <db> function uuid_generate ::tao::uuid_generate
    my <db> function sha1    {::sha1::sha1 -hex}
  }

  method accessTypes {} {
    set accessTypes {admin edit view}
    foreach type [my <db> eval "select distinct right from acl_grants order by right"] {
        logicset add accessTypes $type
    }     
    return $accessTypes    
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
          logicset add rights {*}[my accessTypes]
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
            logicset add rights {*}[my accessTypes]
          } else {
            logicset add rights $right
          }
        }
      }
    }
    return $rights
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
    ###
    # Look for a session id in the query
    ###
    foreach {field value} $result(query) {
      if {$field eq "sessionid"} {
        set stmt {select userid from session where sesid=:value}
        if {[my <db> exists $stmt]} {
          set result(sessionid) $value
          set result(userid) [my <db> one $stmt]
          set result(session) [my <db> eval {select field,value from session_property where sesid=:value}]
          set result(session_delta) $result(session)
          return
        }
      }
    }
    ###
    # Look for a sessionid in cookies
    ###
    foreach {item} [split [get env(HTTP_COOKIE)] ;] {
      set field [lindex [split $item =] 0]
      set value [lindex [split $item =] 1]
      set stmt {select userid from session where sesid=:value}
      if {[my <db> exists $stmt]} {
        set result(sessionid) $value
        set result(userid) [my <db> one $stmt]
        set result(session) [my <db> eval {select field,value from session_property where sesid=:value}]
        set result(session_delta) $result(session)
        return
      }
    }
    if {![info exists result(userid)]} {
      set result(userid) [my <db> one {select userid from users where name='anonymous'}]
    }
    set expdate  [expr {14*86400}]
    set expires [expr {[clock seconds]+$expdate}]]
    if {![info exists result(sessionid)]} {
      # Generate a session
      set sesid [::tao::uuid_generate]
      set result(sessionid) $sesid
      my <db> eval {insert into session(sesid,userid,expires) VALUES (:sesid,:result(userid),:expires)}
    } else {
      my <db> eval {update session set expires=:expires where sesid=:sesid;}
    }
    my cookieSet session $result(sessionid) $expdate
  }
  
  method cookieSet {field value {expire {}}} {
    foreach host [my httpdHostName] {
      if { $host eq "localhost" } { set host {} }
      set cookie_args [list -name $field \
        -value $value \
        -domain $host \
        -path [my cget virtual]]
      if {[string is integer expire]} {
        lappend cookie_args -expires [clock format [expr [clock seconds] + [set expire]] -format "%Y-%m-%d"]
      }
      ::Cookie_Set {*}$cookie_args
    }
  }
  
  method httpdHostName {} {
    my variable env
    return [lindex [split [get env(HTTP_HOST) host] :] 0]
  }
  
  method httpdSessionSave sock {
    # Save any return cookies which have been set.
    # This works with the Doc_SetCookie procedure that populates
    # the global cookie array.
    
    ::Cookie_Save $sock
    if {![info exists result(sessionid)]} return
    my variable result
    set sessionid $result(sessionid)
    
    set add {}
    set delete {}
    set modify {}
    foreach {field value} $result(session) {
      if {![dict exists $result(session_delta) $field]} {
        lappend add $field $value
      } else {$value != [dict get $result(session_delta)]} {
        lappend modify $field $value
      }
    }
    foreach {field value} $result(session_deleta) {
      if {![dict exists $result(session) $field]} {
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
}

package provide httpd::community 0.1
