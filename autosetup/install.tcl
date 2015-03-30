# @synopsis:
#
# Helper script for Makefiles
#

proc use args {
  foreach pkg $args {
    if {[file exists $::here/${pkg}.tcl]} {
      source $::here/${pkg}.tcl
    } elseif {[file exists $::here/../lib/${pkg}.tcl]} {
      source $::here/../lib/${pkg}.tcl
    } else {
      error "Could not find package $args"
    }
  }
}

set ::here [file dirname [file normalize [info script]]]
use fileutil

proc file-normalize args {
  return [file normalize {*}$args]
}
proc _istcl name {
  return [string match *.tcl $name]
}

###
# topic: ea4ac0a84ae990dafee965b995f48e63
###
proc _istm name {
  return [string match *.tm $name]
}

proc _isdirectory name {
  return [file isdirectory $name]
}

foreach {src dest} $argv {
  set src [file normalize $src]
  set dest [file normalize $dest]
  file mkdir $dest
  foreach {file} [fileutil_find $src _istcl] {
    set relname [fileutil_relative $src $file]
    set destfile [file join $dest $relname]
    file mkdir [file dirname $destfile]
    file copy -force $file [file join $dest $relname]
  }
}

