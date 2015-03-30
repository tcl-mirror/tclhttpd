###
# codebale.tcl
#
# This file defines routines used to bundle and manage Tcl and C
# code repositories
#
# Copyright (c) 2014 Sean Woods
#
# See the file "license.terms" for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.
###
#::namespace eval ::codebale {}

# @synopsis:
#
# CODEBALE modules adds autobuild utilities
#

set col 0
use fileutil

###
# topic: e1d75c45e58cc525a0a70ce6f767717c
###
proc codebale_isdirectory name {
  return [file isdirectory $name]
}

###
# topic: d0663852b31759ce78f33cbc63379d84
###
proc codebale_istcl name {
  return [string match *.tcl $name]
}

###
# topic: ea4ac0a84ae990dafee965b995f48e63
###
proc codebale_istm name {
  return [string match *.tm $name]
}

###
# topic: ec0fd469c986351ea0d5a287d6f040d8
###
proc codebale_cases_finalize f {
  global col
  if {$col>0} {puts $f {}}
  set col 0
}

###
# topic: 78728b1f05577d4bc1276e7294ff2cc7
###
proc codebale_cases_generate {prefix cases} {
  global col
  set col 0
  set f [open [file join $::project(path) build [string tolower ${prefix}_cases].h] w]
  fconfigure $f -translation crlf
  puts $f $::project(standard_header)
  puts $f "  const static char *${prefix}_strs\[\] = \173"
  set lx [lsort  $cases]
  foreach item $lx {
    cases_put $f \"[string tolower $item]\",
  }
  cases_put $f 0
  cases_finalize $f
  puts $f "  \175;"
  puts $f "  enum ${prefix}_enum \173"
  foreach name $lx {
    regsub -all {@} $name {} name
    cases_put $f ${prefix}_[string toupper $name],
  }
  cases_finalize $f
  puts $f "  \175;"
  puts $f "\
  int index;
  if( objc<2 ){
    Tcl_WrongNumArgs(interp, 1, objv, \"METHOD ?ARG ...?\");
    return TCL_ERROR;
  }
  if( Tcl_GetIndexFromObj(interp, objv\[1\], ${prefix}_strs,\
            \"option\", 0, &index)){
    return TCL_ERROR;
  }
  switch( (enum ${prefix}_enum)index )"
  close $f
}

###
# topic: 545596e62faedfeda638c8bb703882b1
###
proc codebale_cases_put {f x} {
  global col
  if {$col==0} {puts -nonewline $f "   "}
  if {$col<2} {
    puts -nonewline $f [format " %-21s" $x]
    incr col
  } else {
    puts $f $x
    set col 0
  }
}

###
# topic: 9dd91e4b98b001260e30671883da494b
# description: Generate function declarations
###
proc codebale_headers_csourcefile file {  
  ###
  # Skip huge files
  ###
  if {[file size $file] > 500000} {return {}}
  set fin [open $file r]
  set dat [read $fin]
  close $fin
  set result [digest_csource $dat]
  set functions {}
  if [catch {
  foreach {funcname info} [lsort  -stride 2 [dictGetnull $result function]] {
    dict with info {
      if { "static" in $keywords } continue
      append functions "$keywords $funcname\([join $arglist ", "]\)\x3b" \n
    }
  }
  } err] {
    puts "ERROR Parsing $file: $err"
    return "/*
** $file
** Process cancelled because of errors
** $err
** Line number: $::readinglinenumber
** Line: $::readingline
*/
"
  }
  return $functions
}

###
# topic: c0304a049be6f31206a02d15813720ce
###
proc codebale_meta_output outfile {
  set fout [open $outfile w]
  puts "SAVING TO $outfile"
  
  #puts $fout "array set filemd5 \x7b"
  #array set temp [array get ::filemd5]
  #foreach {file md5} [lsort  [array names temp]] {
  #  set md5 $temp($file)
  #  puts $fout "    [list $file $md5]"
  #}
  #array unset temp
  #puts $fout "\x7d"
  puts $fout "helpdoc eval {begin transaction}"
  helpdoc eval {
    select handle,localpath from repository
  } {
    puts $fout [list ::helpdoc repository_restore $handle [list localpath $localpath]]
  }
  helpdoc eval {
    select hash,fileid from file
  } {
    puts $fout [helpdoc file_serialize $fileid]
  }
  puts $fout [helpdoc node_serialize 0]
  helpdoc eval {
    select entryid from entry
    where class='section'
    order by name
  } {
    puts $fout [helpdoc node_serialize $entryid]
  }
  helpdoc eval {
    select entryid from entry
    where class!='section'
    order by parent,class,name
  } {
    puts $fout [helpdoc node_serialize $entryid]
  }
  puts $fout "helpdoc eval {commit}"
  close $fout
}

###
# topic: cd6e815c2e68b751656a4c9bbe8918dd
# description: Filters extranous fields from meta data
###
proc codebale_meta_scrub {aliases info} {
  foreach {c alist} $aliases {
    foreach a $alist {
      set canonical($a) $c
    }
  }

  set outfo {}
  foreach {field val} $info {
    if {[info exists canonical($field)]} {
      set cname $canonical($field)
    } else {
      set cname $field
    }
    if {$cname eq {}} continue
    if {[string length [string trim $val]]} {
      dict set outfo $cname $val
    }
  }
  return $outfo
}

###
# topic: 51380132b6f872ed01830e34431931d4
###
proc codebale_pkg_mkIndex base {
  set stack {}
  if {[file exists [file join $base pkgIndex.tcl]]} {
    return
    #file delete [file join $base pkgIndex.tcl]
  }
  set fout [open [file join $base pkgIndex.tcl.new] w]
  fconfigure $fout -translation crlf

  set result [::codebale_sniffPath $base stack]
  
  puts $fout {# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.
  }
  
  while {[llength $stack]} {
    set stackpath [lindex $stack 0]
    set stack [lrange $stack 1 end]
    foreach {type file} [::codebale_sniffPath $stackpath stack] { 
      lappend result $type $file
    }
  }
  set i [string length $base]
  foreach {type file} $result {
      switch $type {
          module {
              set fname [file rootname [file tail $file]]
              set package [lindex [split $fname -] 0]
              set version [lindex [split $fname -] 1]
              set dir [string trimleft [string range [file dirname $file] $i end] /]
              puts $fout "package ifneeded $package $version \[list source \[file join \$dir $dir [file tail $file]\]\]"
              #::codebale_read_tclsourcefile $file
          }
          source {
              if { $file == "$base/pkgIndex.tcl" } continue
              if { $file == "$base/packages.tcl" } continue
              if { $file == "$base/main.tcl" } continue
              if { [file tail $file] == "version_info.tcl" } continue
              set fin [open $file r]
              set dat [read $fin]
              close $fin
              if {[regexp "package provide" $dat]} {
                 set fname [file rootname [file tail $file]]
  
                 set dir [string trimleft [string range [file dirname $file] $i end] /]
              
                 foreach line [split $dat \n] {
                    set line [string trim $line]
                    
                    if { [string range $line 0 14] != "package provide" } continue
                    set package [lindex $line 2]
                    set version [lindex $line 3]
                    if { $dir eq {} } {
                      puts $fout "package ifneeded $package $version \[list source \[file join \$dir [file tail $file]\]\]"                      
                    } else {
                      puts $fout "package ifneeded $package $version \[list source \[file join \$dir $dir [file tail $file]\]\]"
                    }
                    break
                 }
              }
              #::codebale_read_tclsourcefile $file
          }
      }
  }
  close $fout
  file rename -force [file join $base pkgIndex.tcl.new] [file join $base pkgIndex.tcl]
}

###
# topic: 924caf1f68529d8dbc329b85e391a1c1
###
proc codebale_pkgindex_manifest base {
  set stack {}
  set output {}
  set base [file-normalize $base]
  set i    [string length  $base]

  foreach {file} [fileutil_find $base codebale_istm] {
    set file [file-normalize $file]
    set fname [file rootname [file tail $file]]
    ###
    # Assume the package is correct in the filename
    ###
    set package [lindex [split $fname -] 0]
    set version [lindex [split $fname -] 1]
    set path [string trimleft [string range [file dirname $file] $i end] /]
    ###
    # Read the file, and override assumptions as needed
    ###
    set fin [open $file r]
    set dat [read $fin]
    close $fin
    foreach line [split $dat \n] {
      set line [string trim $line]
      if { [string range $line 0 9] != "# Package " } continue
      set package [lindex $line 2]
      set version [lindex $line 3]
      break
    }
    lappend output $package $version
  }
  foreach {file} [fileutil_find $base codebale_istcl] {
    set file [file-normalize $file]
    set fin [open $file r]
    set dat [read $fin]
    close $fin
    if {![regexp "package provide" $dat]} continue
    set fname [file rootname [file tail $file]]
    set dir [string trimleft [string range [file dirname $file] $i end] /]
    
    foreach line [split $dat \n] {
      set line [string trim $line]              
      if { [string range $line 0 14] != "package provide" } continue
      set package [lindex $line 2]
      set version [lindex $line 3]
      lappend output $package $version
      break
    }
  }
  return $output
}

###
# topic: 929629f0ebaa554710f66410dfa51f8a
###
proc codebale_pkgindex_path base {
  set stack {}
  set buffer {
lappend ::PATHSTACK $dir
  }
  set base [file-normalize $base]
  set i    [string length  $base]
  # Build a list of all of the paths
  set paths [fileutil_find $base codebale_isdirectory]
  
  foreach path $paths {
    if {$path eq $base} continue
    set path_indexed($path) 0
    foreach idxname {pkgIndex.tcl} {
      if {[file exists [file join $path $idxname]]} {
        incr path_indexed($path)
        set dir [string trimleft [string range $path $i end] /]
        append buffer "
set dir \[file join \[lindex \$::PATHSTACK end\] $dir\] \; source \[file join \[lindex \$::PATHSTACK end\] $dir $idxname\]
"
        append buffer \n
      }
    }
  }

  foreach path $paths {
    if {$path_indexed($path)} continue
    foreach file [glob -nocomplain $path/*.tm] {
      set file [file-normalize $file]
      set fname [file rootname [file tail $file]]
      ###
      # Assume the package is correct in the filename
      ###
      set package [lindex [split $fname -] 0]
      set version [lindex [split $fname -] 1]
      set path [string trimleft [string range [file dirname $file] $i end] /]
      ###
      # Read the file, and override assumptions as needed
      ###
      set fin [open $file r]
      set dat [read $fin]
      close $fin
      foreach line [split $dat \n] {
        set line [string trim $line]
        if { [string range $line 0 9] != "# Package " } continue
        set package [lindex $line 2]
        set version [lindex $line 3]
        break
      }
      append buffer "package ifneeded $package $version \[list source \[file join \[lindex \$::PATHSTACK end\] $path [file tail $file]\]\]"
      append buffer \n
    }
    foreach file [glob -nocomplain $path/*.tcl] {
      set file [file-normalize $file]
      if { $file == [file join $base tcl8.6 package.tcl] } continue
      if { $file == [file join $base packages.tcl] } continue
      if { $file == [file join $base main.tcl] } continue
      if { [file tail $file] == "version_info.tcl" } continue
      set fin [open $file r]
      set dat [read $fin]
      close $fin
      if {![regexp "package provide" $dat]} continue
      set fname [file rootname [file tail $file]]
      set dir [string trimleft [string range [file dirname $file] $i end] /]
      
      foreach line [split $dat \n] {
        set line [string trim $line]              
        if { [string range $line 0 14] != "package provide" } continue
        set package [lindex $line 2]
        set version [lindex $line 3]
        append buffer "package ifneeded $package $version \[list source \[file join \[lindex \$::PATHSTACK end\] $dir [file tail $file]\]\]"
        append buffer \n
        break
      }
    }
  }
  append buffer {
set dir [lindex $::PATHSTACK end]  
set ::PATHSTACK [lrange $::PATHSTACK 0 end-1]
}
  return $buffer
}

###
# topic: 3a00781665184d1efb9e292dbdd1b35c
# title: Read the contents of an rc conf file
# description:
#    This style of conf file is assumed to contain lines formatted
#    set VARNAME VALUE
###
proc codebale_read_rc_file fname {
  if {![file exists $fname]} {
    return {}
  }
  if {![catch {source $fname} err]} {
    # Could read as a Tcl file
    # Fill the result with the contents of
    # all of the local variables defined by
    # that file
    set vars [info vars]
    ldelete vars fname
    foreach var $vars {
      dict set result $var [set $var]
    }
    return $result
  }
  # Parse the file the hard way...
  set fin [open $fname r]
  set thisline {}
  while {[gets $fin line] >= 0} {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    append thisline \n $line
    if {![info complete $thisline]} continue
    # Remove leading \n
    set thisline [string trimleft $thisline]
    if {[string range $line 0 2] == "set"} {
      dict set result [lindex $line 1] [lindex $line 2]
    } else {
      if {[llength $line] eq 2} {
        dict set result [lindex $line 0] [lindex $line 1]
      }
    }
  }
  return $result
}

###
# topic: cbb00d37108708e5968c8a38f73ec38a
###
proc codebale_read_sh_file {filename {localdat {}}} {
  set fin [open $filename r]
  set result {}
  if {$localdat eq {}} {
    set top 1
    set local [array get ::env]
    dict set local EXE {}
  } else {
    set top 0
    set local $localdat
  }
  while {[gets $fin line] >= 0} {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    if {$line eq {}} continue
    catch {
    if {[string range $line 0 6] eq "export "} {
      set eq [string first "=" $line]
      set field [string trim [string range $line 6 [expr {$eq - 1}]]]
      set value [read_sh_subst [string range $line [expr {$eq+1}] end] $local]
      dict set result $field [read_sh_subst $value $local]
      dict set local $field $value
    } elseif {[string range $line 0 7] eq "include "} {
      set subfile [read_sh_subst [string range $line 7 end] $local]
      foreach {field value} [read_sh_file $subfile $local] {
        dict set result $field $value
      }
    } else {
      set eq [string first "=" $line]
      if {$eq > 0} {
        set field [read_sh_subst [string range $line 0 [expr {$eq - 1}]] $local]
        set value [string trim [string range $line [expr {$eq+1}] end] ']
        #set value [read_sh_subst [string range $line [expr {$eq+1}] end] $local]
        dict set local $field $value
        dict set result $field $value
      }
    }
    } err opts
    if {[dict get $opts -code] != 0} {
      #puts $opts
      puts "Error reading line:\n$line\nerr: $err\n***"
      return $err {*}$opts
    }
  }
  return $result
}

###
# topic: 22c2e7ae33fbe0d87784ca9b16df0de4
# description: Converts a XXX.sh file into a series of Tcl variables
###
proc codebale_read_sh_subst {line info} {
  regsub -all {\x28} $line \x7B line
  regsub -all {\x29} $line \x7D line

  #set line [string map $key [string trim $line]]
  foreach {field value} $info {
    catch {set $field $value}
  }
  if [catch {subst $line} result] {
    return {}
  }
  set result [string trim $result]
  return [string trim $result ']
}

###
# topic: 45a5b1e3f8a8372363f1670642972c62
###
proc codebale_shlib_fname {os pkgname pkgvers} {
  if { $os eq "windows" } {
    return lib${pkgname}[string map {. {}} ${pkgvers}].dll
    
  } else {
    switch $os {
      macosx {
        set suffix .dylib
      }
      default {
        set suffix .so
      }
    }
    return lib${pkgname}${pkgvers}$suffix
  }
}

proc realpath path {
  if { !$::odie(windows) } {
    return $path
  }
  if {[string index $path 0] eq "/" && [string index $path 2] eq "/"} {
    return [string index $path 1]:[string range $path 2 end]
  }
  return $path
}

proc cygpath path {
  if { !$::odie(windows) } {
    return $path
  }
  if {[string index $path 1] != ":" } { 
    return $path
  }
  set path [file-normalize $path]
  return /[string tolower [string index $path 0]][string range $path 2 end]
}

proc cygrelative {base filename} {
  set base [::cygpath $base]
  set filename [::cygpath $filename]
  return [::fileutil_relative $base $filename]
}

###
# topic: a5992c7f8340ba02d40e386aac95b1b8
# description: Records an alias for a Tcl keyword
###
proc codebale_alias {alias cname} {
  global cnames
  set cnames($alias) $cname
}

###
# topic: 0e883f3583c0ccd3eddc6b297ac2ea77
###
proc codebale_buffer_append {varname args} {
  upvar 1 $varname result
  if {![info exists result]} {
    set result {}    
  }
  if {[string length $result]} {
    set result [string trimright $result \n]
    append result \n
  }
  set priorarg {}
  foreach arg $args {
    if {[string length [string trim $arg]]==0} continue
    #if {[string match $arg $priorarg]} continue
    set priorarg $arg
    append result \n [string trim $arg \n] \n
  }
  set result [string trim $result \n]
  append result \n
  return $result
}

###
# topic: 926c564aa67884986f7489f37da3fb32
###
proc codebale_buffer_merge args {
  set result {}
  set priorarg {}
  foreach arg $args {
    if {[string length [string trim $arg]]==0} continue
    if {[string match $arg $priorarg]} continue
    set priorarg $arg
    append result [string trim $arg \n] \n
  }
  set result [string trim $result \n]
  return $result
}

###
# topic: c1e66f4a20e397a5d2541714575c165f
###
proc codebale_buffer_puts {varname args} {
  upvar 1 $varname result
  if {![info exists result]} {
    set result {}    
  }
  set result [string trimright $result \n]
  #if {[string length $result]} {
  #  set result [string trimright $result \n]
  #}
  set priorarg {}
  foreach arg $args {
    #if {[string length [string trim $arg]]==0} continue
    #if {[string match $arg $priorarg]} continue
    #set priorarg $arg
    append result \n $arg
    #[string trim $arg \n]
  }
  #set result [string trim $result \n]
  #append result \n
  return $result
}

###
# topic: 951f31f2cb24992f34d97e3deb16b43f
# description: Reports back the canonical name of a tcl keyword
###
proc codebale_canonical alias {
  global cnames
  if {[info exists cnames($alias)]} {
    return $cnames($alias)
  }
  return $alias
}

proc codebale_detect_cases_put_item {f x} {
  upvar 1 col col
  if {$col==0} {puts -nonewline $f "   "}
  if {$col<2} {
    puts -nonewline $f [format " %-21s" $x]
    incr col
  } else {
    puts $f $x
    set col 0
  }
}

proc codebale_detect_cases_finalize {f} {
  upvar 1 col col
  if {$col>0} {puts $f {}}
  set col 0
}

###
# topic: aacfe07625f74f93dada2159f53fca32
###
proc codebale_detect_cases cfile {
  set dirname [file dirname $cfile]
  set fin [open $cfile r]
  while {[gets $fin line] >= 0} {
    if {[regexp {^ *case *([A-Z]+)_([A-Z0-9_]+):} $line all prefix label]} {
      lappend cases($prefix) $label
    }
  }
  close $fin

  set col 0
  
  foreach prefix [array names cases] {
    set hfile [file join $dirname [string tolower $prefix]_cases.h]
    if {[file exists $hfile] && [file mtime $hfile]>[file mtime $cfile]} continue
    set f [open $hfile w]
    fconfigure $f -translation crlf
    puts $f "/*** Automatically Generated Header File - Do Not Edit ***/"
    puts $f "  const static char *${prefix}_strs\[\] = \173"
    set lx [lsort  $cases($prefix)]
    foreach item $lx {
      codebale_detect_cases_put_item $f \"[string tolower $item]\",
    }
    codebale_detect_cases_put_item $f 0
    codebale_detect_cases_finalize $f
    puts $f "  \175;"
    puts $f "  enum ${prefix}_enum \173"
    foreach name $lx {
      regsub -all {@} $name {} name
      codebale_detect_cases_put_item $f ${prefix}_[string toupper $name],
    }
    codebale_detect_cases_finalize $f
    puts $f "  \175;"
    puts $f "\
  int index;
  if( objc<2 ){
    Tcl_WrongNumArgs(interp, 1, objv, \"METHOD ?ARG ...?\");
    return TCL_ERROR;
  }
  if( Tcl_GetIndexFromObj(interp, objv\[1\], ${prefix}_strs,\
            \"option\", 0, &index)){
    return TCL_ERROR;
  }
  switch( (enum ${prefix}_enum)index )"
    close $f
  }
  set result {}
  foreach item [array names cases] {
    lappend result [string tolower ${item}_cases.h]
  }
  return $result
}

###
# topic: 003ce0c0d69b74076e8433492deac920
# description:
#    Descends into a directory structure, returning
#    a list of items found in the form of:
#    type object
#    where type is one of: csource source parent_name
#    and object is the full path to the file
###
proc codebale_sniffPath {spath stackvar} {
  upvar 1 $stackvar stack    
  set result {}
  if { ![file isdirectory $spath] } {
    switch [file extension $spath] {
      .tm {
        return [list parent_name $spath]
      }
      .tcl {
        return [list source $spath]
      }
      .h {
        return [list cheader $spath]
      }
      .c {
        return [list csource $spath]
      }
    }    
    return
  }
  foreach f [glob -nocomplain $spath/*] {
    if {[file isdirectory $f]} {
      if {[file tail $f] in {CVS build} } continue
      if {[file extension $f] eq ".vfs" } continue
      set stack [linsert $stack 0 $f]
    }
  }
  set idx 0
  foreach idxtype {
    pkgIndex.tcl tclIndex
  } {
    if {[file exists [file join $spath $idxtype]]} {
      lappend result index [file join $spath $idxtype]
    }
  }
  if {[llength $result]} {
    return $result
  }
  foreach f [glob -nocomplain $spath/*] {
    if {![file isdirectory $f]} {
      set stack [linsert $stack 0 $f]
    }
  }
  return {}
}


# [dictGetnull] is like [dict get] but returns empty string for missing keys.
proc dictGetnull {dictionary args} {
  if {[dict exists $dictionary {*}$args]} {
    dict get $dictionary {*}$args
  }
}

#namespace ensemble configure dict -map [dict replace\
#    [namespace ensemble configure dict -map] getnull ::tcl::dict::getnull]

if {[info command ::ldelete] eq {}} {
proc ldelete {varname args} {
  upvar 1 $varname var
  if ![info exists var] {
      return
  }
  foreach item [lsort -unique $args] {
    while {[set i [lsearch $var $item]]>=0} {
      set var [lreplace $var $i $i]
    }
  }
  return $var
}  
}


###
# topic: 5b6897b1d60450332ff9f389b5ca952d
###
proc doexec args {
  exec {*}$args >&@ stdout
}

# Simpler version without the substitution
proc read_Config.sh {filename} {
  set fin [open $filename r]
  set result {}
  while {[gets $fin line] >= 0} {
    set line [string trim $line]
    if {[string index $line 0] eq "#"} continue
    if {$line eq {}} continue
    catch {
      set eq [string first "=" $line]
      if {$eq > 0} {
        set field [string range $line 0 [expr {$eq - 1}]]
        set value [string trim [string range $line [expr {$eq+1}] end] ']
        #set value [read_sh_subst [string range $line [expr {$eq+1}] end] $local]
        dict set result $field $value
      }
    } err opts
    if {[dict get $opts -code] != 0} {
      #puts $opts
      puts "Error reading line:\n$line\nerr: $err\n***"
      return $err {*}$opts
    }
  }
  return $result
}

