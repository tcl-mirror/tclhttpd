###
# topic: 4f78c3dbc3f04099f8388b0aaf87df97
# description:
#    This class abstracts the normal operations undertaken
#    my containers and nodes that write to a single data table
###
tao::class taodb::table {
  aliases moac.sqliteTable
  superclass

  # Properties that need to be set:
  # table - SQL Table
  # primary_key - Primary key for the sql table
  # default_record - Key/value list of defaults
  

  ###
  # topic: 6283f1ecde341c8b7dc0199226cfad86
  # title: Delete a record from the database backend
  ###
  method db_record_delete nodeid {
    set table [my property schema table]
    set primary_key [my property schema primary_key]
    my <db> change "delete from $table where $primary_key=:nodeid"
  }

  ###
  # topic: d4c5e9cfea2fa029e80ac21e3173a702
  ###
  method db_record_exists nodeid {
    set table [my property schema table]
    set primary_key [my property schema primary_key]
    return [my <db> exists "select $primary_key from $table where $primary_key=:nodeid"]
  }

  ###
  # topic: e1e4bb66d9cfc158ec9dfb8e13cfe0ce
  # title: Detect record key
  # description: The nodeid of this table from a key/value list of table contents
  ###
  method db_record_key record {
    set primary_key [my property schema primary_key]
    if {[dict exists $record $primary_key]} {
      return [dict get $record $primary_key]
    }
    if {[dict exists $record rowid]} {
      return [dict get $record rowid]
    }
    error "Could not locate the primary key"
  }

  ###
  # topic: 505661a4862772908e986e255ffe1f79
  # description: Read a record from the database
  ###
  method db_record_load {nodeid {arrayvar {}}} {
    if { $arrayvar ne {} } {
      upvar 1 $arrayvar R
    }
    set table [my property schema table]
    if {$nodeid eq {}} {
      return {}
    }
    my <db> eval "select * from $table where rowid=:nodeid" R {}
    unset -nocomplain R(*)
    return [array get R]
  }

  ###
  # topic: 37e78a4cf9ab491f9894c28a128922e4
  # title: Return a record number for a new entry
  ###
  method db_record_nextid {} {
    set primary_key [my property schema primary_key]
    set maxid [my <db> one "select max($primary_key) from [my property schema table]"]
    if { ![string is integer -strict $maxid]} {
      return 1
    } else {
      return [expr {$maxid + 1}]
    }
  }

  ###
  # topic: 0960b530335749a9315d8d05af8c02c2
  # description:
  #    Write a record to the database. If nodeid is negative,
  #    create a new record and return its ID.
  #    This action will also perform any container specific prepwork
  #    to stitch the node into the model, as well as re-read the node
  #    from the database and into memory for use by the gui
  ###
  method db_record_save {nodeid record} {
    appmain signal  dbchange

    set table [my property schema table]
    set primary_key [my property schema primary_key]
    
    set now [clock seconds]
    if { $nodeid < 1 || $nodeid eq {} } {
      set nodeid [my db_record_nextid]
    }
    if {![my <db> exists "select $primary_key from $table where rowid=:nodeid"]} {
      my <db> change "INSERT INTO $table ($primary_key) VALUES (:nodeid)"
      foreach {var val} [my property default_record] {
        if {![dict exists $record $var]} {
          dict set record $var $val
        }
      }
    }
    set oldrec [my db_record_load $nodeid]
    set fields {}
    set values {}
    set stmt "UPDATE $table SET "
    set stmtl {}
    set columns [dict keys $oldrec]
    
    foreach {field value} $record {
        if { $field in [list $primary_key mtime uuid] } continue
        if { $field ni $columns } continue
        if {[dict exists $oldrec $field]} {
            # Screen out values that have not changed
            if {[dict get $oldrec $field] eq $value } continue
        }
        lappend stmtl "$field=\$rec_${field}"
        set rec_${field} $value
    }
    if { $stmtl == {} } {
        return 0
    }
    if { "mtime" in $columns } {
      lappend stmtl "mtime=now()"
    }
    append stmt [join $stmtl ,]
    append stmt " WHERE $primary_key=:nodeid"
    my <db> change $stmt
    return $nodeid
  }
}

###
# topic: 9032e81e051b67fa089f1326da6081f1
# description:
#    Managing records for tables that consist of a primary
#    key and a blob field that contains a key/value list
#    that represents the record
###
tao::class taodb::table.blob {
  aliases moac.sqliteTable.blob
  superclass

  ###
  # topic: 24d95fd922c7d9d188b60b35b382b8dd
  ###
  method db_record_delete nodeid {
    set table        [my property schema table]
    set primary_key  [my property schema primary_key]
    my <db> one "delete from $table where $primary_key=:nodeid"
  }

  ###
  # topic: c4c57639b09ab0f1bd81700cabd6ab88
  ###
  method db_record_load {nodeid {arrayvar {}}} {
    set table  [my property schema table]
    set vfield [my property field_value]
    set primary_key [my property schema primary_key]
    
    if { $arrayvar ne {} } {
      upvar 1 $arrayvar R
      array set R [my <db> one "select $vfield from $table where $primary_key=:nodeid"]
      return [array get R]
    } else {
      return  [my <db> one "select $vfield from $table where $primary_key=:nodeid"]
    }
  }

  ###
  # topic: 268efa2a6aac3451f3e5e525013ec091
  ###
  method db_record_save {nodeid record} {
    set table  [my property schema table]
    set vfield [my property field_value]
    set primary_key [my property schema primary_key]
    
    set result [my property default_record]
    foreach {var val} [my <db> one "select $vfield from $table where $primary_key=:nodeid"] {
      dict set result $var $val
    }
    foreach {var val} $record {
      dict set result $var $val
    }
    my <db> eval "update $table set $vfield=:result where $primary_key=:nodeid"
  }
}

###
# topic: df933b39a39e106c1c0b3f8651d4b5b7
# description:
#    Managing records for tables that consist of a primary
#    key a column representing a "field" and another
#    column representing a "value"
###
tao::class taodb::table.keyvalue {
  aliases moac.sqliteTable.keyvalue
  superclass

  ###
  # topic: c32d751f91d518b47ad400ef04e4f719
  ###
  method db_record_delete nodeid {
    set table        [my property schema table]
    set primary_key  [my property schema primary_key]
    my <db> one "delete from $table where $primary_key=:nodeid"
  }

  ###
  # topic: 34b5a0fefa9a9655a3f8184c3eb640a9
  ###
  method db_record_load nodeid {
    set table  [my property schema table]
    set ffield [my property field_name]
    set vfield [my property field_value]
    set primary_key [my property schema primary_key]

    set result [my property default_record]
    my <db> eval "select $ffield as field,$vfield as value from $table where $primary_key=:nodeid" {
      dict set result $field $value
    }
    return $result
  }

  ###
  # topic: 176679ea4e972f4eac12d4325979369e
  ###
  method db_record_save {nodeid record} {
    set table  [my property schema table]
    set ffield [my property field_name]
    set vfield [my property field_value]
    set primary_key [my property schema primary_key]
    
    set oldrecord [my db_record_load $nodeid]
    foreach {var val} $record {
      if {[dict exists $oldrecord $var]} {
        if {[dict get $oldrecord $var] eq $val } continue
      }
      dict set outrecord $var $val
    }
    if {![llength $outrecord]} return
    
    my <db> transaction {
      foreach {var val} $outrecord {
        my <db> change "insert or replace into $table ($primary_key,$ffield,$vfield) VALUES (:nodeid,$var,$val)"
      }
    }
  }
}

