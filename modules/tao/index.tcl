package provide tao 9.4.4
package require sqlite3
package require TclOO
package require odie
package require listutil 1.7

::namespace eval ::tao {}

###
# topic: f796a2dcb22de645fb365e07d39fce07
###
proc ::tao::load_path {path {ordered_files {}}} {
  if {$::tcl_platform(platform) eq "windows"} {
    if {[string index $path 1] eq ":"} {
      set path [string range $path 2 end]
    }
  }
  lappend loaded index.tcl pkgIndex.tcl
  if {[file exists [file join $path baseclass.tcl]]} {
    lappend loaded baseclass.tcl
    uplevel #0 [list source [file join $path baseclass.tcl]]
  }
  foreach file $ordered_files {
    lappend loaded $file
    uplevel #0 [list source [file join $path $file]]
  }
  foreach file [glob -nocomplain [file join $path *.tcl]] {
    if {[file tail $file] in $loaded} continue
    lappend loaded [file tail $file]
    uplevel #0 [list source $file]
  }
}

###
# topic: b8897eebb90a62e0bac262762116b6b5
###
proc ::tao::script_path {} {
  set path [file dirname [file normalize [info script]]]
  if {$::tcl_platform(platform) eq "windows"} {
    if {[string index $path 1] eq ":"} {
      set path [string range $path 2 end]
    }
  }
  return $path

}

set ::tao::root [::tao::script_path]
::tao::load_path $::tao::root {
  event.tcl
  parser.tcl
  ootools.tcl
  module.tcl
  db.tcl
  moac.tcl
  onion.tcl
  mvc.tcl
}

tao::module pop

