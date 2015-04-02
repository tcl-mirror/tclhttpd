::namespace eval ::tao {}

::namespace eval ::tao::event {}

::namespace eval ::tao::info {}

::namespace eval ::tao::parser {}

::namespace eval ::tao::signal {}

###
# topic: 643efabec4303b20b66b760a1ad279bf
###
proc ::tao::args_to_dict args {
  if {[llength $args]==1} {
    return [lindex $args 0]
  }
  return $args
}

###
# topic: b40970b0d9a2525990b9105ec8c96d3d
###
proc ::tao::args_to_options args {
  set result {}
  foreach {var val} [args_to_dict {*}$args] {
    lappend result [string trimleft $var -] $val
  }
  return $result
}

###
# topic: 396899726d57640d3e90a2caa180d855
# title: Return the canonical name of a class
###
proc ::tao::canonical name {
  set class ::[string trimleft $name :]
  ::tao::db eval {select cname from class_alias where alias=:class} {
    set class $cname
  }
  return $class
}

###
# topic: da87af1492df6d913beb343d9b534d1c
# title: Create or modify a tao class
# description:
#    This command is an enhancement to [emph {::oo::class create}] and [emph {oo::define}].
#    In addition to the normal behavior expected from these operations, [emph tao::class]
#    tracks the class in the [emph tao::db] as well as rebuild the dynamic methods
###
proc ::tao::class {name body} {
  set class [canonical $name]
  if { [::info command $class] == {} } {
    ::tao::metaclass create $class
  }
  ::tao::parser::push $class
  namespace eval ::tao::parser $body
  ::tao::parser::pop
  ::tao::dynamic_methods $class
  foreach {rname} [::tao::db eval {select name from class where regenerate!=0}] {
    ::tao::dynamic_methods $rname
  }
  set ::tao::coreclasses [::tao::db eval {select class from class_property where type='classinfo' and property='type' and dict='core'}]
}

###
# topic: 87e896b8994dba3927f227685169a939
###
proc ::tao::class_ancestors {class {stackvar {}}} {
  if { $stackvar ne {} } {
    upvar 1 $stackvar stack
  } else {
    set stack {}
  }
  if { $class in $stack } {
    return {}
  }
  lappend stack $class
  if {![catch {::info class superclasses $class} ancestors]} {
    foreach ancestor $ancestors {
      class_ancestors $ancestor stack
    }
  }
  if {![catch {::info class superclasses $class} ancestors]} {
    foreach ancestor $ancestors {
      class_ancestors $ancestor stack
    }
  }
  return $stack
}

###
# topic: 19f6ce3edca7d84e2f7d82e8a7e9035f
# description: Return a list of tao classes
###
proc ::tao::class_choices {} {
  return [lsort -dictionary $::tao::info:::class]
}

###
# topic: 8a0deafc19c1f3605a7ca961ec2ab01f
###
proc ::tao::class_descendents {class {stackvar {}}} {
  if { $stackvar ne {} } {
    upvar 1 $stackvar stack
  } else {
    set stack {}
  }
  if { $class in $stack } {
    return {}
  }
  lappend stack $class
  foreach {child} [::tao::db eval {select class from class_ancestor where ancestor=:class}] {
    class_descendents $child stack
  }
  return $stack
}

###
# topic: 8c73a1ebe15b4935a4ff657399742257
###
proc ::tao::class_destroy class {
  if {[dict exists $::tao::info::class $class]} {
    dict unset ::tao::info::class $class
  }
  ::tao::db eval {
delete from class_property where class=:class;
delete from class_ensemble where class=:class;
delete from class_typemethod where class=:class;
delete from class_alias where cname=:class;
delete from class_ancestor where class=:class or ancestor=:class;
  }
}

###
# topic: 4969d897a83d91a230a17f166dbcaede
###
proc ::tao::dynamic_arguments {arglist args} {
  set idx 0
  set len [llength $args]
  if {$len > [llength $arglist]} {
    ###
    # Catch if the user supplies too many arguments
    ###
    set dargs 0
    if {[lindex $arglist end] ni {args dictargs}} {
      set string [dynamic_wrongargs_message $arglist]
      error $string
    }
  }
  foreach argdef $arglist {
    if {$argdef eq "args"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      break
    }
    if {$argdef eq "dictargs"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      ###
      # Perform args processing in the style of tao
      ###
      set dictargs [::tao::args_to_options {*}[lrange $args $idx end]]
      uplevel 1 [list set dictargs $dictargs]
      break
    }
    if {$idx > $len} {
      ###
      # Catch if the user supplies too few arguments
      ###
      if {[llength $argdef]==1} {
        set string [dynamic_wrongargs_message $arglist]
        error $string
      } else {
        uplevel 1 [list set [lindex $argdef 0] [lindex $argdef 1]]
      }
    } else {
      uplevel 1 [list set [lindex $argdef 0] [lindex $args $idx]]
    }
    incr idx
  }
}

###
# topic: a92cd258900010f656f4c6e7dbffae57
###
proc ::tao::dynamic_methods class {
  set ancestors [::tao::db eval {select ancestor from class_ancestor where class=:class order by CAST(seq as INTEGER);}]
  set order 0
  set script {}
  
  ::tao::dynamic_methods_ensembles $class $ancestors
  ::tao::dynamic_methods_class    $class $ancestors
  ::tao::dynamic_methods_property $class $ancestors
  ::tao::db eval {update class set regenerate=0 where name=:class;}
}

###
# topic: b88add196bb63abccc44639db5e5eae1
###
proc ::tao::dynamic_methods_class {thisclass ancestors} {
  set cmethods {}
  foreach anc $ancestors {
    ::tao::db eval {select method,arglist,body from class_typemethod where class=:anc} {
      if { $method in $cmethods } continue
      lappend cmethods $method
      ::oo::objdefine $thisclass method $method $arglist $body
    }
  }
}

###
# topic: fb8d74e9c08db81ee6f1275dad4d7d6f
###
proc ::tao::dynamic_methods_ensembles {thisclass ancestors} {

  set ensembledict {}
  #set trace [string match $thisclass "::taotk::sqlconsole"]
  set trace 0
  if {$trace} { puts "dynamic_methods_ensembles $thisclass"}
  foreach ancestor $ancestors {
    if {$trace} { puts $ancestor }
    ::tao::db eval {select * from class_ensemble where class=:ancestor} {
      if {[dict exists $ensembledict $ensemble $method]} continue
      if { $trace } { puts "$ensemble :: $method from $ancestor"}
      dict set ensembledict $ensemble $method [list $arglist $body]
    }
  }

  foreach {ensemble einfo} $ensembledict {
    set eswitch {}
    set default standard
    if {[dict exists $einfo default]} {
      set emethodinfo [dict get $einfo default]
      set arglist     [lindex $emethodinfo 0]
      set realbody    [lindex $emethodinfo 1]
      set body "\n      ::tao::dynamic_arguments [list $arglist] {*}\$args"
      append body "\n      " [string trim $realbody] "      \n"
      set default $body
      dict unset einfo default
    }
    set eswitch \n
    append eswitch "\n    [list <list> [list return [lsort -dictionary [dict keys $einfo]]]]" \n
    foreach {submethod} [lsort -dictionary [dict keys $einfo]] {
      set esubmethodinfo [dict get $einfo $submethod]
      set arglist     [lindex $esubmethodinfo 0]
      set realbody    [lindex $esubmethodinfo 1]
      if {[string length [string trim $realbody]] eq {}} {
        append eswitch "    [list $submethod {}]" \n
      } else {
        set body "\n      ::tao::dynamic_arguments [list $arglist] {*}\$args"
        append body "\n      " [string trim $realbody] "      \n"
        append eswitch "    [list $submethod $body]" \n
      }
    }
    if {$default=="standard"} {
      set default "error \"unknown method $ensemble \$method. Valid: [lsort -dictionary [dict keys $eswitch]]\""
    }
    append eswitch [list default $default] \n
    set body {}
    append body \n "set code \[catch {switch -- \$method [list $eswitch]} result opts\]"

    #if { $ensemble == "action" } {
    #  append body \n {  if {$code == 0} { my event generate event $method {*}$dictargs}}
    #}
    append body \n {return -options $opts $result}
    oo::define $thisclass method $ensemble {{method default} args} $body
    # Define a property for this ensemble for introspection
    ::tao::parser::property ensemble_methods $ensemble [lsort -dictionary [dict keys $einfo]]
  }
  if {$trace} { puts "/dynamic_methods_ensembles $thisclass"}

}

###
# topic: 6b7879602c202398bd25f733c0933cf9
###
proc ::tao::dynamic_methods_property {thisclass ancestors} {
  ###
  # Apply properties
  ###  
  set info {}
  dict set info option {}
  set proplist {}
  foreach ancestor $ancestors {
    ::tao::db eval {select property,type,dict from class_property where class=:ancestor} {
      if {[dict exists $info $type $property]} continue
      dict set info $type $property $dict
      if { $type in {eval const subst variable}} {
        # For these values, we want to exclude equivilent calls
        if {[dict exists $info eval $property]} continue
        if {[dict exists $info const $property]} continue
        if {[dict exists $info subst $property]} continue
        lappend proplist $property
        set mdef [split $property _]
        if {[llength $mdef] > 1} {
          set ptype [lindex $mdef 0]
          lappend proptypes($ptype) $property
        }
      }     
    }
  }
  
  set publicvars {}
  ###
  # Build options
  ###
  set option_classes [dict getnull $info option_class]
  # Build option handlers
  foreach {property pdict} [dict getnull $info option] {
    set contents {
      default {}
    }
    #append body \n " [list $property "return \[my cget [list $property]\]"]"
    set optionclass [dict getnull $pdict class]
    if {[dict exists $option_classes $optionclass]} {
      foreach {f v} [dict get $option_classes $optionclass] {
        dict set contents [string trimleft $f -] $v
      }
    }
    if {[dict exists $info option $optionclass]} {
      foreach {f v} [dict get $info option $optionclass] {
        dict set contents [string trimleft $f -] $v
      }
    }
    foreach {f v} $pdict {
      dict set contents [string trimleft $f -] $v
    }
    dict set info option $property $contents
  }
  
  dict set info meta class $thisclass
  dict set info meta ancestors $ancestors
  dict set info meta signal_order [::tao::signal_order [dict getnull $info signal]]
  dict set info meta types [lsort -dictionary -unique [array names proptypes]]
  dict set info meta local [get proplist]
  ###
  # Build the body of the property method
  ###
  set commonbody "switch \$field \{"
  append commonbody \n "  [list class [list return $thisclass]]"
  append commonbody \n "  [list ancestors [list return $ancestors]]"
  
  foreach {type typedict} $info {
    set typebody "    switch \[lindex \$args 0\] \{"
    append typebody \n "    [list list [list return [lsort -unique -dictionary [dict keys $typedict]]]]"
    append typebody \n "    [list dict [list return $typedict]]"
    foreach {subprop value} $typedict {
      switch $type {
        variable {
          append typebody \n "    [list $subprop [list return $value]]"          
        }
        default {
          append typebody \n "    [list $subprop [list return $value]]"          
        }
      }
    }
    append typebody "\n    \}" \n
    append commonbody \n "  [list $type $typebody]"
  }
  # Build const property handlers
  foreach {property pdict} [dict getnull $info const] {
    append commonbody \n " [list $property [list return $pdict]]"   
  }
  set body {
my variable config
if {[llength $args]==0} {
  if {[dict exists $config $field]} {
    return [dict get $config $field]
  }
}
  }
  append body $commonbody
  append classbody $commonbody

  # Build eval property handlers
  foreach {property pdict} [dict getnull $info eval] {
    if {$property in $proplist} continue
    append body \n " [list $property $pdict]"
  }

  # Build subst property handlers
  foreach {property pdict} [dict getnull $info subst] {
    if {$property in $proplist} continue
    append body \n " [list $property [list return [subst $pdict]]]"
  }
  
  # Build option handlers
  foreach {property pdict} [dict getnull $info option] {
    dict set publicvars $property $pdict
    append body \n " [list $property "return \[my cget [list $property]\]"]"
  }  
  
  # Build public variable handlers
  foreach {property pdict} [dict getnull $info variable] {
    dict set publicvars $property $pdict
    append body \n " [list $property "my variable $property \; return \$property\]"]"
  }

  # End of switch
  append body \n "\}"
  append classbody \n "\}"

  append body \n {return {}}
  
  oo::define $thisclass method property {field args} $body
  oo::objdefine $thisclass method property {field args} $classbody
}

###
# topic: 53ab28ac5c6ee601fe1fe07b073be88e
###
proc ::tao::dynamic_wrongargs_message arglist {
  set result "Wrong # args: should be:"
  set dargs 0
  foreach argdef $arglist {
    if {$argdef in {args dictargs}} {
      set dargs 1
      break
    }
    if {[llength $argdef]==1} {
      append result " $argdef"
    } else {
      append result " ?[lindex $argdef 0]?"
    }
  }
  if { $dargs } {
    append result " ?option value?..."
  }
  return $result
}

###
# topic: cd54fcd0eef299655f36c9d1e1454d53
###
proc ::tao::macro {name arglist body} {
  proc ::tao::parser::$name $arglist $body
}

###
# topic: cf50771bb0664678ec3857b360c25aab
# title: Go nowhere, do nothing
###
proc ::tao::noop args {}

###
# topic: 9e8830a711a1a888fb4c94c75bd46bad
# description: Register the existence of an object
###
proc ::tao::object_create object {
}

###
# topic: d42790a731ce9e3ff1866e71f9c42f17
# description: Unregister an object from the odie event manager
###
proc ::tao::object_destroy object {  
  variable trace
  if { $trace } {
    puts [list ::tao::object_destroy $object]
  }
  ::tao::event::generate $object destroy {}
  ###
  # Cancel any events
  ###
  ::tao::event::cancel $object *
  set names [list $object {*}[::tao::db eval {select alias from object_alias where cname=:object}]]
  foreach name $names {
    if {[dict exists $::tao::info::object $name]} {
      dict unset ::tao::info::object $name
    }

    ::tao::db eval {
delete from object where name=:name;
delete from object_bind where object=:name;
delete from object_subscribers where sender=:name;
delete from object_subscribers where receiver=:name;
delete from object_alias where cname=:name or alias=:name;
    }
  }
}

###
# topic: d9ebb42dd1ce3ecde3905b57f96109ab
###
proc ::tao::object_rename {object newname} {
  variable trace
  if { $trace } {
    puts [list ::tao::object_rename $object -> $newname]
  }
  rename $object ::[string trimleft $newname]
  ::tao::db eval {
update object_alias set cname=:newname where cname=:object;
update object set name=:newname where name=:object;
update object_bind set object=:newname where object=:object;
update object_subscribers set sender=:newname where sender=:object;
update object_subscribers set receiver=:newname where receiver=:object;

insert or replace into object_alias(cname,alias) VALUES (:newname,:object);
}
}

###
# topic: 6f46e5ab32dc211c4f838aec8d187c17
###
proc ::tao::Signal_compare {i j sigdat {trace 0}} {
  if {$i == $j} {
    return 0
  }

  set j_preceeds_i [Signal_matches $j [dict get $sigdat $i preceeds]]
  set i_preceeds_j [Signal_matches $i [dict get $sigdat $j preceeds]]
  set j_follows_i [Signal_matches $j [dict get $sigdat $i follows]]
  set i_follows_j [Signal_matches $i [dict get $sigdat $j follows]]

  if {$i_preceeds_j && !$j_preceeds_i && !$i_follows_j} {
    return -1
  }
  if {$j_preceeds_i && !$i_preceeds_j && !$j_follows_i} {
    return 1
  }
  if {$j_follows_i && !$i_follows_j} {
    return 1
  }
  if {$i_follows_j && !$j_follows_i} {
    return -1
  }
  set j_triggers_i [Signal_matches $j [dict get $sigdat $j triggers]]
  set i_triggers_j [Signal_matches $i [dict get $sigdat $i triggers]]
  return 0
}

###
# topic: 1f4128fa725b7af77fc6458fe653a651
###
proc ::tao::signal_expand {rawsignal sigdat {signalvar {}}} {
  if {$signalvar ne {}} {
    upvar 1 $signalvar result
  } else {
    set result {}
  }
  if {$rawsignal in $result} {
    return {}
  }
  if {[dict exists $sigdat $rawsignal]} {
    lappend result $rawsignal
    # Map triggers
    foreach s [dict get $sigdat $rawsignal triggers] {
      signal_expand $s $sigdat result
    }
  } else {
    # Map aliases
    foreach {s info} $sigdat {
      if {$rawsignal in [dict get $info aliases]} {
        signal_expand $s $sigdat result
      }
    }
  }
  return $result
}

###
# topic: a92545861c81e86de17b19b008507776
###
proc ::tao::Signal_matches {signal fieldinfo} {
  foreach value $fieldinfo {
    if {[string match $value $signal]} {
      return 1
    }
  }
  return 0
}

###
# topic: 9cfad45cdb257837b13844261768286e
###
proc ::tao::signal_order sigdat {
  set allsig [lsort -dictionary [dict keys $sigdat]]
  
  foreach i $allsig {
    set follows($i) {}
    set preceeds($i) {}
  }
  foreach i $allsig {
    foreach j $allsig {
      if { $i eq $j } continue
      set cmp [Signal_compare $i $j $sigdat]
      if { $cmp < 0 } {
        ::ladd follows($i) $j
      }
    }
  }
  # Resolve mutual dependencies
  foreach i $allsig {
    foreach j $follows($i) {
      foreach k $follows($j) {
        if {[Signal_compare $i $k $sigdat] < 0} {
          ::ladd follows($i) $k
        }
      }
    }
  }
  foreach i $allsig {
    foreach j $follows($i) {
      ::ladd preceeds($j) $i
    }
  }
  # Start with sorted order
  set order $allsig
  set pass 0
  set changed 1
  while {$changed} {
    set changed 0
    foreach i $allsig {
      set iidx [lsearch $order $i]
      set max $iidx
      foreach j $preceeds($i) {
        set jidx [lsearch $order $j]
        if {$jidx > $max } {
          set after $j
          set max $jidx
        }
      }
      if { $max > $iidx } {
        set changed 1
        set order [lreplace $order $iidx $iidx]
        set order [linsert $order [expr {$max + 1}] $i]
      }
    }
    if {[incr pass]>10} break
  }
  return $order
}

###
# topic: de8ee09c5a76e55364264b1e7a4b8003
###
proc ::tao::singleton {name body} {
  set class ::[string trimleft $name :].class
  #::ladd ::tao::class_list $class
  if { [::info command $class] == {} } {
    ::tao::metaclass create $class
  }
  ::tao::parser::push $class
  namespace eval ::tao::parser $body
  ::tao::parser::pop

  foreach {rname} [::tao::db eval {select name from class where regenerate!=0}] {
    ::tao::dynamic_methods $rname
  }
  $class create $name
}

