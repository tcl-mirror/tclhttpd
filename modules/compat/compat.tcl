package provide httpd::compat 4.0

namespace eval ::httpd {}
set ::httpd::compat_dir [file dirname [file normalize [info script]]]

proc httpd::compat_level level {
  set cfiles {}
  foreach file [lsort -dictionary -decreasing [glob -nocomplain [file join $::httpd::compat_dir version-*.tcl]]] {
    set version [lindex [split [file tail $file] -] 1]
    if { "$version" >= $level } { source $file }
  }
}