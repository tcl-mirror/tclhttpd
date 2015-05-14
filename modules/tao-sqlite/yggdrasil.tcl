###
# Structure that manages an interactive help system
###
package provide ::tao::helpdoc 0.1

###
# topic: f5641520f17f23259b96facbe936c875
###
tao::class taodb::yggdrasil {
  aliases tao.yggdrasil
  superclass taodb::module.sqlite
  
  property schema create_sql {
    CREATE TABLE if not exists config(
      name TEXT PRIMARY KEY,
      value ANY
    );
    create table if not exists entry (
      entryid string default (uuid_generate()),
      indexed integer default 0,
      parent integer references entry (entryid),
      class string,
      name string,
      mtime integer,
      primary key (entryid)
    );
    create table if not exists property (
      entryid    string references entry (entryid),
      field      string,
      value      string,
      primary key (entryid,field)
    );
    create table if not exists link (
      linktype string,
      entry integer references entry (entryid),
      refentry integer references entry (entryid)
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
      repo           string references repository (handle),
      path           string,  --path relative to repo
      localpath      string,  --cached path to local file
      filename       string,  --filename
      content_type   string,  --Content/Type of file
      package        string,  --Name of any packages provided,
      size           integer, --File size in bytes
      mtime          integer, --mtime in unix time
      hash           string,   --md5 hash of file
      primary key (fileid)
    );
    create table if not exists filelink (
      linktype string,
      entryid integer references entry (entryid),
      fileid integer references file   (fileid)
    );
  }
  
  
  property create_index_sql {
    create index if not exists nameidx on entry (entryid,name);
    create index if not exists parentidx on entry (parent,entryid);    
  }
  

  ###
  # topic: ce057acc3716a2d568a7031702a08db6
  ###
  method alias_list class {
    return [my <db> eval {select alias,cname from aliases where class=:class order by cname,alias}]
  }

  ###
  # topic: 181987917bb442b19b20c6a381b68e65
  ###
  method canonical {class name} {
    set name [string tolower $name]
    if { $class in {{} * any}} {
      return [my <db> eval {select distinct class from aliases order by class}]
    }
    if { $name in {{} * any}} {
      return [my <db> eval {select alias,cname from aliases where class=:class order by cname,alias}]
    }
    set rows [my <db> eval {select entryid from entry where class=:class and name=:name}]
    if {[llength $rows] == 1} {
      return $name
    }
    if {[my <db> exists {select cname from aliases where class=:class and (alias=:name or cname=:name)}]} {
      return [my <db> one {select cname from aliases where class=:class and (alias=:name or cname=:name) limit 1}]
    }
  }

  ###
  # topic: e1fb31429cfba5b9c8939b3089d7dccf
  ###
  method canonical_aliases {class name} {
    set name [string tolower $name]
    return [my <db> eval {select distinct alias from aliases where class=:class and cname=:name and alias!=:name}]
  }

  ###
  # topic: 9892395f48e5568923ee0516ca23313a
  ###
  method canonical_id {class name} {
    return [my <db> eval {select id from idset where class=:class and name=:name}]
  }

  ###
  # topic: 0e2b411c94df5cdc082f6d909045f44c
  ###
  method canonical_set {type name cname} {
    set class [string tolower $type]
    set name [string tolower $name]
    set cname [string tolower $cname] 
    variable canonical_name
    dict set canonical_name $class $name $cname
    set address $type/$name
    my <db> eval {replace into aliases (class,alias,cname) VALUES ($class,$name,$cname)}
  }

  ###
  # topic: a3ee1a620e5659107eea8b3f9ef38b0d
  ###
  method class_list class {
    return [lsort -dictionary [my <db> eval {select name from entry where class=:class}]]
  }

  ###
  # topic: 7e5caa43f37e38328ca83784db16face
  ###
  method class_nodes class {
    set result {}
    foreach {entryid name} [my <db> eval {select entryid,name from entry where class=:class order by name}] {
      lappend result $name [my node_properties $entryid]
    }
    return $result
  }

  ###
  # topic: 85fa5fdaecfbc8a8236d726b37adc8b8
  ###
  method enum_dump class {
    return [my <db> eval {select id,name from idset where class=:class order by id}]
  }

  ###
  # topic: 54b27245e29c98708a964c0739583737
  ###
  method enum_id {class name} {
    set arr ::irm::${class}_name_to_idx
    if {![info exists $arr]} {
      my <db> eval {select name as aname,id as aid from idset where class=:class} {
        set ${arr}($aname) $aid
      }
    }
    set cname [my canonical $class $name]
    if {![info exists ${arr}($cname)]} {
      error "Invalid $class $name"
    }
    return [set ${arr}($cname)]
  }

  ###
  # topic: 944e9861c8d04a693896c7a093bcb641
  ###
  method enum_name {class id} {
    return [my <db> one {select name from idset where class=:class and id=:id}]
  }

  ###
  # topic: ff79f9268801cbdbf06bee1d0827a8ed
  ###
  method enum_set {class name id} {
    set class [string tolower $class]
    set name [string tolower $name]
    set ::irm::${class}_name_to_idx($name) $id
    set ::irm::${class}_idx_to_name($id) $name
    my <db> eval {insert or replace into idset (class,id,name) VALUES ($class,$id,$name)}
  }

  ###
  # topic: 848689c2e58328b9da8b97afee687e52
  ###
  method file_hash {rawfileid {newhash {}}} {
    set fileid [my file_id $rawfileid]
    if {$fileid ne {}} {
      return [my <db> one {select hash from file where fileid=:fileid}]
    }
    return {}
  }

  ###
  # topic: 438f616e49033a8d7215330112d314ad
  ###
  method file_id {addr {create 0}} {
    if {[my <db> exists {select fileid from file where fileid=:addr}]} {
      return $addr
    }
    if {[my <db> exists {select fileid from file where hash=:addr}]} {
      return [my <db> one {select fileid from file where hash=:addr}]
    }
    if {[llength $addr]==2} {
      set repo [lindex $addr 0]
      set path [lindex $addr 1]
      if {[my <db> exists {select fileid from file where repo=:repo and path=:path}]} {
        return [my <db> one {select fileid from file where repo=:repo and path=:path}]
      }
    }
    if {[my <db> exists {select fileid from file where path=:addr}]} {
      return [my <db> one {select fileid from file where path=:addr}]
    }
    if {[my <db> exists {select fileid from file where localpath=:addr}]} {
      return [my <db> one {select fileid from file where localpath=:addr}]
    }
    if {$create} {
      set newuuid [my <db> one {select uuid_generate()}]
      if {[llength $addr]==2} {
        set repo [lindex $addr 0]
        set path [lindex $addr 1]
        my <db> eval {insert into file (fileid,repo,path) VALUES (:newuuid,:repo,:path);}
      } else {
        my <db> eval {insert into file (fileid,path) VALUES (:newuuid,:path);}
      }
      return $newuuid
    }
    return {}
  }

  ###
  # topic: c2cab41e44bb7cdcca831e05aa5ef902
  ###
  method file_restore {nodeid info} {
    set stmtl {}
    dict with info {}
    set fileid [my file_id $nodeid 1]
    set stmt "UPDATE file SET "
    set stmtl {}
    foreach {field value} $info {
      switch $field {
        repo -
        path -
        localpath -
        filename -
        content_type -
        package -
        size -
        mtime -
        hash {
          if { $value ne {} } {
            set _$field $value
            lappend stmtl "$field=:_${field}"
          }
        }
      }
    }
    if {![llength $stmt]} return
    append stmt "[join $stmtl ,]"
    append stmt " where fileid=:fileid"
    my <db> eval $stmt
  }

  ###
  # topic: fba89244d9f7fba909fb01dc7a25535a
  ###
  method file_serialize nodeid {
    set result {}
    my <db> eval {
      select * from file
      where fileid=$nodeid
    } record {
      set fileid $record(fileid)
      append result "[list [self] file_restore [list $record(repo) $record(path)]] \{" \n
      
      foreach {field value} [array get record] {
        if { $field in {* fileid indexed export} } continue
        append result "  [list $field $value]" \n
      }
      append result "\}"
    }
    return $result
  }

  ###
  # topic: f8abb1cd4c82172741704b789371c706
  # title: Build a full text index
  ###
  method full_text_index {{force 0}} {
    my <db> eval {
    CREATE TABLE if not exists config(
      name TEXT PRIMARY KEY,
      value ANY
    );
    }
    if {!$force && [my <db> exists {select * from config where name='fts_indexed' and value='1'}]} {
      return
    }
    
    my <db> eval {
DROP TABLE IF EXISTS search;
CREATE VIRTUAL TABLE search USING fts4(uuid,class,title,body);
insert into search (uuid,class,title,body)
  SELECT entry.entryid,entry.class,entry.name,property.value
  FROM entry,property where entry.entryid=property.entryid and field='description';

INSERT OR REPLACE INTO config(name,value) VALUES ('fts_indexed',1);
    }
  }

  ###
  # topic: 6892a2438c56b5e207888f6683d684cc
  ###
  method link_create {entryid to {type {}}} {
    if { $type eq {} } {
      set exists [my one {select count(entry) from link where entry=$entryid and refentry=$to}]
      if {!$exists} {
        my <db> eval {insert or replace into link (entry,refentry) VALUES ($entryid,$to)}
      }
    } else {
      set exists [my one {select count(entry) from link where entry=$entryid and refentry=$to and linktype=$type}]
      if {!$exists} {
        my <db> eval {insert or replace into link (entry,refentry,linktype) VALUES ($entryid,$to,$type)}
      } 
    }
  }

  ###
  # topic: bebaa55db9d00f615f4c3e589b9f5cca
  ###
  method link_detect_address args {
    set args [string tolower $args]
    if {[my node_exists $args entryid]} {
      return [my <db> eval {select entryid from entry where entryid=$entryid}]
    }
    ###
    # If the link contains a / we know it is a hard
    # path
    ###
    if {[my node_exists $args entryid]} {
      return $entryid
    }
    if {[llength $args] > 1} {
      set rootentries [my <db> eval {select name from entry where class='section'}]
      
      if {[lindex $args 0] in $rootentries} {
        set type [lindex $args 0]
        set name [my canonical $type [lindex $args 1]]
        if {[my node_exists [list $type $name] entryid]} {
          return $entryid
        }
      }
      if {[lindex $args 1] in $rootentries} {
        set type [lindex $args 1]
        set name [my canonical $type [lindex $args 0]]
        if {[my node_exists [list $type $name] entryid]} {
          return $entryid
        }
      }
    }
    set addr [lindex $args 0]
    set cnames [my <db> eval {select class,cname from aliases where alias=$addr}]
  
    if {[llength $cnames] == 2} {
      if {[my node_exists $cnames entryid]} {
        return $entryid
      }
    }
    #if {[string first / $addr] > 0 } {
    #  return $addr
    #}
    set candidates [my <db> eval {select entryid,name from entry where name like '%$addr%'}]
    foreach address $candidates {
      if {[regexp simnode $address]} {
        return $address
      }
    }
    #puts [list CAN'T RESOLVE $args]
    return $args
  }

  ###
  # topic: 4be4c2c74388621448494e1ced97fccb
  # description:
  #    Return a list of all children of node,
  #    Filter is a key/value list that understands
  #    the following:
  #    type - Limit children to type
  #    dump - Output the contents of the child node, not their id
  ###
  method node_children {nodeid class} {
    set dump 1
    set entryid [my node_id $nodeid]
    if { $class eq {} } {
      set nodes [my <db> eval {select name,entryid from entry where parent=$entryid}]
    } else {
      set nodes [my <db> eval {select name,entryid from entry where parent=$entryid and class=$class}]
    }
    if {!$dump} {
      return $nodes
    }
    set result {}
    foreach {cname cid} $nodes {
      dict set result $cname [my <db> eval {select field,value from property where entryid=$cid order by field}]
    }
    return $result
  }

  ###
  # topic: 1ddcdaedcca9f6bf1d17564fc2b80dbe
  ###
  method node_define {class name info {nodeidvar {}}} {
    if {$nodeidvar ne {}} {
      upvar 1 $nodeidvar nodeid
    }
    set class [string tolower $class]
    set name  [string tolower $name]
    if { $class eq {} || $class eq "section" } {
      set nodeid $name
    } else {
      set nodeid {}
      if {[dict exists $info topic]} {
        set nodeid [dict get $info topic]
        dict unset info topic
      }
    }    
    if { $nodeid eq {} } {
      if {![my node_exists [list $class $name] nodeid]} {
        set nodeid [helpdoc node_id [list $class $name] 1]
        foreach {var val} [my node_empty $class] {
          my node_property_set $nodeid $var $val        
        }
      }
    } elseif {![my node_exists $nodeid]} {
      my canonical_set $class $name $name
      my <db> eval {insert into entry (entryid,class,name) VALUES (:nodeid,:class,:name)}
      foreach {var val} [my node_empty $class] {
        my node_property_set $nodeid $var $val        
      }
    }
  
    foreach {var val} $info {
      my node_property_set $nodeid $var $val
    }
  }

  ###
  # topic: 5cf8420243fb46472b33a18cb340f8cf
  ###
  method node_define_child {parent class name info {nodeidvar {}}} {
    if {$nodeidvar ne {}} {
      upvar 1 $nodeidvar nodeid
    }
    ###
    # Return an already registered node with this address
    ###
    if {[my <db> exists {select entryid from entry where parent=:parent and class=:class and name=:name}]} {
      set nodeid [my <db> one {select entryid from entry where parent=:parent and class=:class and name=:name}]
    } else {
      set nodeid {}
  
      if {[dict exists $info topic]} {
        set topicid [dict get $info topic]
        dict unset info topic
        if {![my <db> exists {select entryid from entry where entryid=:topicid}]} {
          # If we are recycling an unused UUID re-create the entry in the table
          my <db> eval {insert or replace into entry (entryid,parent,class,name) VALUES (:topicid,:parent,:class,:name)}
          set nodeid $topicid
        }
      }
      if { $nodeid eq {} } {
        set nodeid [::tao::uuid_generate $parent $class $name]
      }
      if {[my <db> exists {select entryid from entry where entryid=:nodeid and class=:class and name=:name}]} {
        ###
        # Correct a misfiled node
        ###
        my <db> eval {update entry set parent=:parent where entryid=:nodeid}
      } else {
        my <db> eval {insert or replace into entry (entryid,parent,class,name) VALUES (:nodeid,:parent,:class,:name)}
      }
      foreach {var val} [my node_empty $class] {
        if {![dict exists $info $var]} {
          dict set info $var $val
        }
      }
    }
    foreach {var val} $info {
      my node_property_set $nodeid $var $val        
    }
    return $nodeid
  }

  ###
  # topic: 1ce63e18b2072f0218695df90c83b5e6
  ###
  method node_empty class {
    set id [my <db> one {select entryid from entry where name=:class and class='section'}]
    return [my <db> one {select value from property where entryid=:id and field='template'}]
  }

  ###
  # topic: 8a70c9ed461c3728787f2e5385f8be66
  ###
  method node_exists {node {resultvar {}}} {
    set parent 0
    if { $resultvar != {} } {
      upvar 1 $resultvar row
    }
    if {[llength $node]==1} {
      set name [lindex $node 0]
      if {[my <db> exists {select entryid from entry where name=:name or entryid=:name}]} {
        set row [my <db> one {select entryid from entry where name=:name or entryid=:name}]
        return 1
      }
    } elseif {[llength $node]==2} {
      set class [lindex $node 0]
      set name [lindex $node 1]
      if {[my <db> exists {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]} {
        set row [my <db> one {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]
        return 1
      }
    }
    set class [lindex $node 0]
    set name [lindex $node 1]
    if {[my <db> exists {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]} {
      set parent [my <db> one {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]
    } else {
      return 0
    }
    foreach {eclass ename} [lrange $node 2 end] {
      set row {}
      if {$eclass eq {}} {
        if {[my <db> exists {select entryid from entry where parent=:parent and (entryid=:ename or name=:ename)}]} {
          set row [my <db> one {select entryid from entry where parent=:parent and (entryid=:ename or name=:ename)}]
        }
      } else {
        if {[my <db> exists {select entryid from entry where parent=:parent and class=:eclass and (entryid=:ename or name=:ename)}]} {
          set row [my <db> one {select entryid from entry where parent=:parent and class=:eclass and (entryid=:ename or name=:ename)}]
        }
      }
      if { $row eq {} } {
        return 0
      }
      set parent $row
    }
    return 1
  }

  ###
  # topic: 6c3e041a03a5b2bcf5c6fdab1721d7b6
  ###
  method node_get {nodeid {field {}}} {
    set result {}
    if {[my node_exists $nodeid entryid]} {
      set result [helpdoc node_properties $entryid]
    } else {
      if {[llength $nodeid] > 1} {
        set type [lindex $nodeid 0]
        set result [my node_empty $type]
      }
    }
    if { $field eq {} } {
      return $result    
    }
    return [dict getnull $result $field]
  }

  ###
  # topic: bdeb89732bc42953dedf39bce57ab75b
  ###
  method node_id {node {create 0}} {
    if {[my <db> exists {select entryid from entry where entryid=:node;}]} {
      return [my <db> one {select entryid from entry where entryid=:node;}]
    }
    if {[llength $node]==1} {
      set name [lindex $node 0]
      if {[my <db> exists {select entryid from entry where name=:name or entryid=:name}]} {
        return [my <db> one {select entryid from entry where name=:name or entryid=:name}]
      }
      if { $create } {
        my <db> eval {insert into entry (class,name) VALUES ('section',:name)}
        return $name
      } else {
        error "Node $node does not exist"
      }
    } elseif {[llength $node]==2} {
      set class [lindex $node 0]
      set name [lindex $node 1]

      if {[my <db> exists {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]} {
        set row [my <db> one {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]
        return $row
      }
    }
    set class [lindex $node 0]
    set name [lindex $node 1]
    if {[my <db> exists {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]} {
      set parent [my <db> one {select entryid from entry where (class=:class or parent=:class) and (name=:name or entryid=:name)}]
    } else {
      if {!$create} {
        error "Node $node does not exist"
      }

      ###
      # If the name contains no spaces, dots, slashes, or ::
      ###
      set row [::tao::uuid_generate $class $name]
      my <db> eval {insert into entry (entryid,class,name) VALUES (:row,:class,:name)}
      set parent $row
    }
    if { $create } {
      set classes [my <db> eval {select distinct class from entry}]
    }
    set eclass {}
    foreach token [lrange $node 2 end] {
      set ename $token
      set row {}
      if {$eclass eq {}} {
        if {[my <db> exists {select entryid from entry where parent=:parent and (entryid=:ename or name=:ename)}]} {
          set row [my <db> one {select entryid from entry where parent=:parent and (entryid=:ename or name=:ename)}]
        }
      } else {
        if {[my <db> exists {select entryid from entry where parent=:parent and class=:eclass and (entryid=:ename or name=:ename)}]} {
          set row [my <db> one {select entryid from entry where parent=:parent and class=:eclass and (entryid=:ename or name=:ename)}]
        }
      }
      if { $row eq {} } {
        if { $create } {
          if { $ename in $classes } {
            set eclass $token
            continue            
          } else {
            set eclass {}
            my node_define_child $parent $eclass $ename {} row
          }          
        } else {
          error "Node $node does not exist"
        }
      }
      set parent $row
    }
    return $row
  }

  ###
  # topic: 6f5dc7fcf3eb6204800a7b910d283483
  ###
  method node_properties entryid {
    return [my <db> eval {select field,value from property where entryid=$entryid}]
  }

  ###
  # topic: 51611e18a49da769364ef583f439e8a2
  ###
  method node_property_append {nodeid field text} {
    set buffer [my one {select value from property where entryid=:nodeid and field=:field}]
    append buffer " " [string trim $text]
    my <db> eval {insert or replace into property (entryid,field,value) VALUES (:nodeid,:field,:buffer)}
  }

  ###
  # topic: 79b939dca06915d886b2d6c0a393e803
  ###
  method node_property_get {nodeid field} {
    return [my <db> one {select value from property where entryid=:nodeid and field=:field}]
  }

  ###
  # topic: cecb9e2416c9fec272e7beb9d4c183df
  # description: nodeid is any value acceptable to [lb]my node_alloc[rb]
  ###
  method node_property_lappend {entryid field args} {
    if {![llength $args]} return
    set dbvalue [my <db> eval {select value from property where entryid=$entryid and field=$field}]
    foreach value $args {
      if { $value eq {} } continue
      ::ladd dbvalue $value
    }
    my <db> eval {update property set value=$dbvalue where entryid=$entryid and field=$field}
  }

  ###
  # topic: 3f633c4bdd0fe22bb94870976e2e3aa8
  ###
  method node_property_set {entryid args} {
    my variable property_info property_cname
    if {[llength $args]==1} {
      set arglist [lindex $args 0]
    } else {
      set arglist $args
    }
    foreach {field value} $arglist {
      if {[info exists property_cname($field)]} {
        set cname $property_cname($field)
        set rawvalue $value
        eval [dict getnull $property_info $cname script]
      } else {
        set cname $field
      }
      if {![my <db> exists {select value from property where entryid=:entryid and field=:cname and value=:value}]} {
        my <db> eval {insert or replace into property (entryid,field,value) VALUES (:entryid,:cname,:value)}
      }
    }
  }

  ###
  # topic: 7a941df07b5299ec365d98e284ca4442
  ###
  method node_restore {nodeid info} {
    set stmtl {}
    dict with info {}
    set fields entryid
    set _entryid $nodeid
    set values "\$_entryid"
    
    foreach {field value} $info {
      switch $field {
        properties {
          foreach {var val} $value {
            my node_property_set $_entryid $var $val
          }
        }
        references {
          foreach {refid reftype} $references {
            my link_create $_entryid $refid $reftype
          }
        }
        enumid {
          my enum_set [lindex $value 0] [dict get $info name] [lindex $value 1]
        }
        aliases {
          foreach a $value {
            my canonical_set $_class $a $_name
          }
        }
        parent {
          if {![string is integer $value]} {
            set value [my node_id $value 1]
          }
          lappend fields $field
          lappend values "\$_$field"
          set _$field $value            
        }
        class -
        address -
        name {
          if { $value ne {} } {
            lappend fields $field
            lappend values "\$_$field"
            set _$field $value
          }
        }
      }
    }
    my <db> eval "insert or replace into entry ([join $fields ,]) VALUES ([join $values ,]);"
  }

  ###
  # topic: 399c322eb03e90aacbc10ae171557cfd
  ###
  method node_serialize nodeid {
    set result {}
    my <db> eval {
      select * from entry
      where entryid=$nodeid
    } record {
      set entryid $record(entryid)
      append result "[list [self] node_restore $entryid] \{" \n
      
      foreach {field value} [array get record] {
        if { $field in {* entryid indexed export} } continue
        append result "  [list $field $value]" \n
      }
      set class $record(class)
  
      set id [my canonical_id $class $record(name)]
      if { $id ne {} } {
          append result "  [list enumid [list $class $id]]" \n
      }
      
      append result "  properties \{" \n
      set info [my node_empty $record(class)]
      foreach {var val} [my node_properties $entryid] {
        dict set info $var $val
      }

      foreach {var} [lsort -dictionary [dict keys $info]] {
        if { $var in {aliases field method fields methods references id} } continue
        append result "    [list $var [string trim [dict get $info $var]]]" \n
      }
      
      append result "  \}" \n
      set references [my <db> eval {select refentry,linktype from link where entry=$entryid}]
      if {[llength $references]} {
        append result "  [list references $references]" \n
      }
      set aliases [my canonical_aliases $record(class) $record(name)]
      if {[llength $aliases]} {
        append result "  [list aliases $aliases]" \n
      }
      set attachments [my <db> eval {select file.hash,filelink.linktype from file,filelink where filelink.entryid=$entryid and filelink.fileid=file.fileid}]
      if {[llength $attachments]} {
        append result "  [list attachments $attachments]" \n
      }
      append result "\}"
    }
    return $result
  }

  ###
  # topic: 841e0e684d5dd1035ed56316e3a075b2
  ###
  method property_define {property info} {
    my variable property_info property_cname
    foreach {f v} $info {
      dict set property_info $property $f $v
    }
    foreach alias [dict getnull $property_info $property aliases] {
      set property_cname($alias) $property
    }
    set property_cname($property) $property
  }

  ###
  # topic: db9d2312731e0b51f1cf0ce4f597ecdb
  ###
  method reindex {} {
    my variable canonical_name
    my <db> eval {select class,alias,cname from aliases order by class,cname,alias} {
      dict set canonical_name $class $alias $cname
    }
  }

  ###
  # topic: 5b3aeab40382b22c6a5dda372de4faec
  ###
  method repository_restore {handle info} {
    set stmtl {}
    dict with info {}
    set fields handle
    set _handle $handle
    set values "\$_handle"
    foreach {field value} $info {
      switch $field {
        localpath {
          if { $value ne {} } {
            lappend fields $field
            lappend values "\$_$field"
            set _$field $value
          }
        }
      }
    }
    my <db> eval "insert or replace into repository ([join $fields ,]) VALUES ([join $values ,]);"
  }
}

interp alias {} tao.yggdrasil {} ::taodb::yggdrasil

