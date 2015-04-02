###
# topic: d3e536874747b4e5a6b879e6f2422cd4
# description: Modules are objects that wrap around sqlite connections
###
tao::class taodb::module.sqlite {
  superclass taodb::connection.sqlite
  
  constructor filename {
    package require sqlite3
    
    if [catch {
      my Database_Attach $filename
      ###
      # Allow up to 2 seconds of
      # slack time for another process to
      # write to the database
      ###
      my <db> timeout 2000
    }] {
      puts "Falling back to temporary storage"
      my Database_Attach {}
    }
    return 0
  }

  ###
  # topic: 6292ac0c78dbb91c7aaa629f48a301a3
  ###
  method Database_Create {} {
    my <db> eval [my property create_sql]
  }

  ###
  # topic: 582bb8d10136f632866e73a6b72a9c32
  ###
  method Database_Functions {} {
    my <db> function uuid_generate ::tao::uuid_generate
  }
}

