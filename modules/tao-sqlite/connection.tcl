###
# topic: 1f4bc558d601dd0621d4f441fcf94b07
# title: High level database container
# description:
#    A taodb::connection
#    <p>
#    This object is assumed to be a nexus of an sqlite connector
#    and several subject objects to manage the individual tables
#    accessed by this application.
###
tao::class taodb::connection {
  superclass tao.onion
  property docentry {}

  ###
  # topic: 124b0e5697a3e0a179a5bc044c735a54
  ###
  method active_layers {} {
    # Return a mapping of tables to their handler classes
    return {}
  }

  ###
  # topic: ad8b51dd1884240d87d7a99ee2a8b862
  ###
  method Database_Create {} {
  }

  ###
  # topic: 7cb96867401c18478a3dfb74b4cd37d8
  ###
  method Database_Functions {} {
  }

  ###
  # topic: 62f531b6d83adc8a10d15b27ec17b675
  ###
  method schema::create_sql {} {
    set result {}
    foreach {layer obj} [my layers] {
      set table [$obj property schema table]
      append result "-- BEGIN $table" \n
      append result [$obj property schema create_sql] \n
      append result "-- END $table" \n
    }
    return $result
  }

  ###
  # topic: fb34f12af081276e36172acfbbea52cf
  ###
  method schema::tables {} {
    set result {}
    foreach {layer obj} [my layers] {
      set table [$obj property schema table]
      lappend result $table
    }
    return $result
  }
}

###
# topic: eaf5daa1dd0baa5e8501e97af3224656
# title: High level database container
# description: A taodb::connection implemented for sqlite
###
tao::class taodb::connection.sqlite {
  superclass taodb::connection tao::onion
  aliases moac.sqliteDb


  option filename {
    widget filename
    extensions {.sqlite {Sqlite Database}}
  }

  option read-only {
    default 0
    widget boolean
  }
  
  option timeout {
    default 30000
    type integer
  }

  ###
  # topic: f71dcb5b2e2312180e379356f3263ff9
  ###
  method attach_sqlite_methods sqlchan {
    my graft db $sqlchan
foreach func {
authorizer
backup
busy
cache
changes
close
collate
collation_needed
commit_hook
complete
copy
enable_load_extension
errorcode
eval
exists
function
incrblob
last_insert
last_insert_rowid
nullvalue
one
onecolumn
profile
progress
restore
rollback_hook
status
timeout
total_changes
trace
transaction
unlock_notify
update_hook
version
    } {
        my forward $func $sqlchan $func
    }
  }

  ###
  # topic: 93c3c991254fd21abc02add7babe5b51
  # title: Evaluate an SQL expression that alters the database
  # description:
  #    This method is a wrapper around "eval" that will catch
  #    "not authorized" messages and give the user some notice that
  #    they should rename the file before altering it.
  ###
  method change args {
    if {[my cget read-only]} {
      my message readOnlyDatabase
      return
    }
    uplevel 1 [list [self] eval {*}$args]
  }

  ###
  # topic: 8a8ecce021e1fcbf8fc25be3ce4cd1d5
  ###
  method Database {submethod args} {
    return [my Database_$submethod {*}$args]
  }

  ###
  # topic: ba1114cdc19c7835f848f9c6ce2f21c7
  ###
  method Database_Attach filename {
    set alias db
    if { $filename in {:memory: {}}} {
      set exists 0
    } else {
      set exists [file exists $filename]
    }
    my put filename $filename
    set objname [my SubObject $alias]
    sqlite3 $objname $filename
    ###
    # Register our busy method
    ###
    $objname busy [namespace code {my Database_Busy}]
    ###
    # Wait up to 2 seconds for
    # a busy database
    ###
    $objname timeout [my cget timeout]
    my graft $alias $objname
    my Database_Functions
    my attach_sqlite_methods $objname
    if {!$exists} {
      my Database_Create
    }
  }

  ###
  # topic: 6319133f765170f9949de3e3329bf07f
  # description:
  #    Action to perform when database is busy
  #    return "1" to cause action to fail,
  #    0 to allow Sqlite to wait and try again
  ###
  method Database_Busy {} {
    update
    return 0
  }

  ###
  # topic: 4251a1e7abd66d20c66f9dcd25bb1e54
  # description:
  #    Deep wizardry
  #    Disable journaling and disk syncronization
  #    If the app crashes, we really don't give a
  #    rat's ass about the output, anyway
  ###
  method journal_mode onoff {
    # Store temporary tables in memory
    if {[string is false $onoff]} {
      my <db> eval {
PRAGMA synchronous=0;
PRAGMA journal_mode=MEMORY;
PRAGMA temp_store=2;
      }
    } else {
      my <db> eval {
PRAGMA synchronous=2;
PRAGMA journal_mode=DELETE;
PRAGMA temp_store=0;
      }
    }
  }

  ###
  # topic: 9363820d1352dc0b02d8b433be02a5b7
  ###
  method message::readonly {} {
    error "Database is read-only"
  }

  ###
  # topic: 29d3a99d20a7f3aaa7911b2666bdf17e
  ###
  method native::table_info table {
    set info {}
    my one {select type,sql from sqlite_master where tbl_name=$table} {
      foreach {type field value} [::schema::createsql_to_dict $sql] {
        dict set info $type $field $value
      }
    }
    return $info
  }

  ###
  # topic: df7ff05563eae14512f945ac80b18ea6
  ###
  method native::tables {} {
      return [my eval {SELECT name FROM sqlite_master WHERE type ='table'}]
  }

  ###
  # topic: 4e2dc71f459beab3d31cd49f012340fb
  ###
  method Option_set::filename filename {
    my Database_Attach $filename
  }

  ###
  # topic: d5591c09b59c6a8d50001af79d108e13
  ###
  method SubObject::db {} {
    return [namespace current]::Sqlite_db
  }
}

