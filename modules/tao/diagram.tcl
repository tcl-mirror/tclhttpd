::namespace eval ::tao {}

###
# topic: 9f2e173840e3307fb6bd47e72e3d2451
# title: Generate a graphviz diagram of the current object hierarchy
###
proc ::tao::diagram {base filename {ignorefunct ::tao::diagram_ignore}} {
  set fout [open $filename w]
  puts $fout {
/*
* @command = dot
*
*/
  }
  puts $fout "digraph g \{"
  puts $fout {
rankdir = LR;
compound=true;

  }
#layout = dot
#compound = true  
#  
  set direct 1
  set classlist {}
  if { $base in {* all}} {
    ::tao::db eval {select name from class order by name} {
      if {[$ignorefunct $name]} continue
      lappend classlist $name
    }
  } else {
    foreach b $base {
      ::tao::db eval {select name from class where package=:b order by name} {
        if {[$ignorefunct $name]} continue
        lappend classlist $name
        ::tao::db eval {select class from class_ancestor where ancestor=:name and direct=1} {
          if { $class in $classlist } continue
          lappend classlist $class
        }
      }
    }
  }
  ::tao::db eval "select * from class where name in ('[join $classlist ',']')" {
    ladd modules($package) $name
    dict set classinfo $name display [diagram_name $name]
    dict set classinfo $name module  $package
    dict set classinfo $name connections [::tao::db eval "select ancestor from class_ancestor where (class=:name and direct=1) order by seq desc;"]
  }
  set graphid 0
  foreach {module mclasses} [lsort -dictionary -stride 2 [array get modules]] {
    puts $fout "  subgraph \"module[incr graphid]\" \{"
    set includes {}
    foreach class $mclasses {
      if {[$ignorefunct $class]} continue
      lappend includes [diagram_name $class]
      set links [dict get $classinfo $class connections]
      foreach {link direct} $links {
        if { $link eq $class } continue
        if {[$ignorefunct $link]} continue
        if {[string is true -strict $direct] } {
          lappend indirect([diagram_name $link]) [diagram_name $class]           
        } elseif { $link in $mclasses } {
          puts $fout "  [diagram_name $link]->[diagram_name $class]\;"
        } else {
          lappend extlinks([diagram_name $link]) [diagram_name $class] 
        }
      }
    }
    #puts $fout "    rank=same; [join $includes \;]"
    puts $fout "    [join $includes \;]"
    puts $fout "    label = \"Module $module\"\;"
    puts $fout "    color=lightgrey;"
    puts $fout "\}"
  }
  
  foreach {class links} [lsort -dictionary -stride 2 [array get extlinks]] {
    foreach link $links {
      puts $fout "  $class->$link\;"
    }
  }

  foreach {class info} [get classinfo] {
    dict with info {}
    puts $fout "$display \[shape = box\; label=\"[string trimleft $class :]\"\]\;"
  }

  puts $fout "\}"
  close $fout
}

###
# topic: c4dd91d51fb5ab26ec90c39ed4dbd306
###
proc ::tao::diagram_class {base filename {show_indirect 0} {ignorefunct ::tao::diagram_ignore}} {

#layout = dot
#compound = true  
#  
  set direct 1
  set classlist {}

  set direct 0
  set classlist $base
  foreach bclass $base {
    ::tao::db eval {select class from class_ancestor where ancestor=:bclass} {
      if { $class in $classlist } continue
      lappend classlist $class
    }
    ::tao::db eval {select ancestor from class_ancestor where class=:bclass} {
      if { $ancestor in $classlist } continue
      lappend classlist $ancestor
    }
  }

  
  ::tao::db eval "select * from class where name in ('[join $classlist ',']')" {
    ladd modules($package) $name
    dict set classinfo $name display [diagram_name $name]
    dict set classinfo $name module  $package
    ::tao::db eval "select ancestor,direct from class_ancestor where (class=:name and ancestor in ('[join $classlist ',']')) order by seq desc;" {
      if {[$ignorefunct $ancestor]} continue
      if { $ancestor eq $name } continue
      if { !$direct } {
        lappend indirect([diagram_name $ancestor]) [diagram_name $name]
      } else {
        lappend extlinks([diagram_name $ancestor]) [diagram_name $name] 
      }
    }
  }
  if {[info exists classinfo]} return

  set fout [open $filename w]
  puts $fout {
/*
* @command = dot
*
*/
  }
  puts $fout "digraph g \{"
  puts $fout {
rankdir = LR;
compound=true;

  }
  foreach {class links} [lsort -dictionary -stride 2 [array get extlinks]] {
    foreach link $links {
      puts $fout "  $class->$link\;"
    }
  }
  if { $show_indirect } {
    puts $fout "  edge \[color=red\]\;"
    foreach {class links} [lsort -dictionary -stride 2 [array get indirect]] {
      foreach link $links {
        puts $fout "  $class->$link\; "
      }
    }
  }
  foreach {class info} $classinfo {
    dict with info {}
    puts $fout "$display \[shape = box\; label=\"[string trimleft $class :]\"\]\;"
  }

  puts $fout "\}"
  close $fout
}

###
# topic: f1b91f039c8be1c604563a6624af84fe
###
proc ::tao::diagram_ignore class {
  if { $class in {::tao::moac ::oo::class ::oo::object} } {
    return 1
  }
  return 0
}

###
# topic: c7e2d0be0393921331e4476ff0a77e5a
###
proc ::tao::diagram_name name {
  set result {}
  foreach i [split $name :] {
    if { $i ne {} } {
      lappend result [join [split $i .] _]
    }
  }
  return [join $result _]
}

