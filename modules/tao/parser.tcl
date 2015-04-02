::namespace eval ::tao {}

::namespace eval ::tao::parser {}

###
# topic: 5832132afd4f65a0dd404f834e7fce7f
# title: Specify other names that this class will answer to
###
proc ::tao::parser::aliases args {
  set class [peek]
  foreach name $args {
    set alias ::[string trimleft $name :]
    set cname [::tao::db one {select cname from class_alias where alias=:alias}]
    if { $cname ni [list {} $class] } {
      error "$alias is already an alias for $cname"
    }
    ::tao::db eval {
insert into class_alias(cname,alias) VALUES (:class,:alias);
}
  }
}

###
# topic: 7a5c7e04989704eef117ff3c9dd88823
# title: Specify the a method for the class object itself, instead of for objects of the class
###
proc ::tao::parser::class_method {name arglist body} {
  set class [peek]
  method $name $arglist $body
  ::tao::db eval {insert or replace into class_typemethod (class,method,arglist,body) VALUES (:class,:name,:arglist,:body);}
}

###
# topic: 710a93168e4ba7a971d3dbb8a3e7bcbc
###
proc ::tao::parser::component args {
  
}

###
# topic: 2cfc44a49f067124fda228458f77f177
# title: Specify the constructor for a class
###
proc ::tao::parser::constructor {arglist rawbody} {
  set body {
::tao::object_create [self]
my InitializePublic
  }
  append body $rawbody
  append body {
# Remove lock constructor
my lock remove constructor
  }
  ::oo::define [peek] constructor $arglist $body
}

###
# topic: 4cb3696bf06d1e372107795de7fe1545
# title: Specify the destructor for a class
###
proc ::tao::parser::destructor rawbody {
  set body {
::tao::object_destroy [self]
  }
  append body $rawbody
  ::oo::define [peek] destructor $body
}

###
# topic: ec9ca249b75e2667ad5bcb2f7cd8c568
# title: Define an ensemble method for this agent
###
::proc ::tao::parser::method {rawmethod args} {
  set class [peek]
  set mlist [split $rawmethod "::"]
  if {[llength $mlist]==1} {
    set method $rawmethod
    set arglist [lindex $args 0]
    set body [lindex $args 1]
    ::oo::define $class method $rawmethod {*}$args
    return
  }
  set ensemble [lindex $mlist 0]
  set method [join [lrange $mlist 2 end] "::"]
  switch [llength $args] {
    1 {
      set arglist dictargs
      set body [lindex $args 0]
      ::tao::db eval {
insert or replace into class_ensemble(class,ensemble,method,arglist,body) VALUES
(:class,:ensemble,:method,:arglist,:body)}
    }
    2 {
      set arglist [lindex $args 0]
      set body [lindex $args 1]
      ::tao::db eval {
insert or replace into class_ensemble(class,ensemble,method,arglist,body) VALUES
(:class,:ensemble,:method,:arglist,:body)}
    }
    default {
      error "Usage: method NAME ARGLIST BODY"
    }
  }
}

###
# topic: 68aa446005235a0632a10e2a441c0777
# title: Define an option for the class
###
proc ::tao::parser::option {name args} {
  set class [peek]
  set dictargs {default {}}
  foreach {var val} [::tao::args_to_dict {*}$args] {
    dict set dictargs [string trimleft $var -] $val
  }
  set name [string trimleft $name -]
  
  ###
  # Mirrored Option Handling
  ###
  set mirror [dict getnull $dictargs mirror]
  if {[llength $mirror]} {
    if {![dict exists $dictargs signal]} {
      set signal {}
      foreach i $mirror {
        set sname option_mirror_$i
        lappend signal $sname
        if {![::tao::db exists {select * from class_property where (class=:class or class in (select ancestor from class_ancestor where class=:class)) and type='signal' and property=:sname}]} {
          ::tao::parser::signal $sname [string map [list %signal% sname %organ% $i] {
            action {
              if {[my organ %organ%] ne {}} {
                my %organ% configure {*}[my OptionsMirrored %organ%]
              }
            }
          }]
        }
      }
      dict set dictargs signal $signal
    }
  }
  property option $name $dictargs
}

###
# topic: 827a3a331a2e212a6e301f59c1eead59
# title: Define a class of options
# description:
#    Option classes are a template of properties that other
#    options can inherit.
###
proc ::tao::parser::option_class {name args} {
  set class [peek]
  set dictargs {default {}}
  foreach {var val} [::tao::args_to_dict {*}$args] {
    dict set dictargs [string trimleft $var -] $val
  }
  set name [string trimleft $name -]
  property option_class $name $dictargs
}

###
# topic: baeb5170936f985e0e97be63018bc130
# title: Internal function
# description: Returns the current class being processed
###
proc ::tao::parser::peek args {
  if {[llength $args] == 2} {
    upvar 1 [lindex $args 0] class [lindex $args 1] docnode 
  }
  ::variable classStack
  set class   [lindex $classStack end]
  return ${class}
}

###
# topic: 1c598e92d29ba0311212b3fdf2334b34
# title: Internal function
# description: Removes the current class being processed from the parser stack.
###
proc ::tao::parser::pop {} {
  ::variable classStack
  set class      [lindex $classStack end]
  set classStack [lrange $classStack 0 end-1]

  tao::db eval {update class set regenerate=1 where name=:class}
  # Signal for all decendents to regenerate
  foreach d [::tao::class_descendents $class] {
    tao::db eval {update class set regenerate=1 where name=:d}
  }
  return $class
}

###
# topic: 83160a2aba9dfa455d82b46cdd2e4127
# title: Define the properties for this class as a key/value list
###
proc ::tao::parser::properties args {
  set class [peek]
  switch [llength $args] {
    1 {
      foreach {var val} [lindex $args 0] {
        ::tao::db eval {insert or replace into class_property (class,type,property,dict) VALUES (:class,'const',:var,:val);}
      }
    }
    2 {
      set type [lindex $args 0]
      foreach {var val} [lindex $args 1] {
        ::tao::db eval {insert or replace into class_property (class,type,property,dict) VALUES (:class,:type,:var,:val);}
      }
    }
    default {
      error "Usage: property ?type? infodict"
    }
  }
}

###
# topic: 709b71e10365e576653d00f185ca9efd
# title: Define a single property for this class
# description: If no type is given [emph const] is assumed.
# darglist: [opt [arg type]] [arg name] [arg value]
###
proc ::tao::parser::property args {
  set class [peek]
  switch [llength $args] {
    2 {
      set type const
      set property [lindex $args 0]
      set value [lindex $args 1]
    }
    3 {
      set type     [lindex $args 0]
      set property [lindex $args 1]
      set value    [lindex $args 2]
    }
    default {
      error "Usage: property ?type? field value"
    }
    default {
      error "Usage:
property name typet valuedict
OR property name value"
    }
  }
  if { $type eq {} } {
    set type eval
  }
  ::tao::db eval {insert or replace into class_property (class,type,property,dict) VALUES (:class,:type,:property,:value);}
}

###
# topic: bd23198ef1938428fb1532dd96de2c12
# description: Push a class onto the stack
###
proc ::tao::parser::push type {
  ::variable classStack
  lappend classStack $type
  if {![::tao::db exists {select name from class where name=:type}]} {
    ::tao::db eval {insert into class(name,package,regenerate) VALUES (:type,$::tao::module,1);}
  }
  if {![dict exists $::tao::info::class $type]} {
    dict set ::tao::info::class $type {
      aliases   {}
      ancestors {}
      regenerate 1
      property {}
      ensemble {}
      superclass {::tao::moac}
    }
  } else {
    dict set ::tao::info::class $type regenerate 1
  }
}

###
# topic: 4d12b6ca2823d960a81e6f15fd9962e6
# title: Create a signal for this class
# description:
#    Really just a wrapper for [emph {property signal}]. However,
#    this keyword ensures manditory fields are given.
###
proc ::tao::parser::signal {name infodict} {
  set result {
    apply_action {}
    action       {}
    aliases      {}
    comment      {}
    excludes     {}
    preceeds     {}
    follows      {}
    triggers     {}
  }
  dict set result name $name
  foreach {f v} $infodict {
    dict set result $f $v
  }
  property signal $name $result
}

###
# topic: 2f74ddd49a0c8e8f92e73a843acca2d7
# title: Specify ancestors for this class
# description:
#    This keyword mimics the behavior of the TclOO [emph superclass]
#    keyword. In addition to the TclOO connotations, this keyword
#    also indexes the class in the in-memory database.
#    [para]
#    For classes with no ancestors, call this keyword with no arguments.
#    Failure to do so will cause problems with the property method.
#    [para]
#    This function will also map classes classes refered to by alias.
###
proc ::tao::parser::superclass args {
  set class [peek]
  set ancestors {}
  set direct {}
  set rawvalue {}
  foreach item $args {
    set anc ::[string trimleft $item :]
    set item $anc
    if {[::tao::db exists {select cname from class_alias where alias=:anc}]} {
      set item [::tao::db one {select cname from class_alias where alias=:anc}]
    }
    lappend rawvalue $item
  }
  foreach item $rawvalue {
    if { $item in {::tao::moac ::oo::class} } continue
    if { $item in $::tao::coreclasses } continue
    lappend direct $item
    if { $item ni $ancestors && $item ne $class } {
      lappend direct $item
      lappend ancestors $item
    }
  }
  foreach item $rawvalue {
    if { $item in {::tao::moac ::oo::class} } continue
    if { $item ni $::tao::coreclasses } continue
    lappend direct $item
    if { $item ni $ancestors && $item ne $class } {
      lappend direct $item
      lappend ancestors $item
    }
  }
  if { $class ne "::tao::moac" } {
    lappend ancestors ::tao::moac
  }
  ::tao::db eval {update class set superclass=:ancestors where name=:class}
  ::oo::define $class superclass {*}$ancestors
  
  set order -1
  ::tao::db eval {delete from class_ancestor where class=:class}
  set ancestors [::tao::class_ancestors $class]
  foreach d $ancestors {
    incr order
    ::tao::db eval {insert into class_ancestor(class,seq,ancestor,direct) VALUES (:class,:order,:d,0);}
  }
  foreach d $direct {
    ::tao::db eval {update class_ancestor set direct=1 where class=:class and ancestor=:d}
  }
  property meta ancestors $ancestors
}

###
# topic: 615b7c43b863b0d8d1f9107a8d126b21
# title: Specify a variable which should be initialized in the constructor
# description:
#    This keyword can also be expressed:
#    [example {property variable NAME {default DEFAULT}}]
#    [para]
#    Variables registered in the variable property are also initialized
#    (if missing) when the object changes class via the [emph morph] method.
###
proc ::tao::parser::variable {name {default {}}} {
  property variable $name [list default $default]
}

###
# topic: c5f7c9ada6fe1605219273b957283d70
# description: Work space for the IRM class parser
###
namespace eval ::tao::parser {
  foreach keyword {
    deletemethod export filter forward  renamemethod
    self unexport unknown
  } {
    proc $keyword args "::oo::define \[peek\] $keyword {*}\$args"
  }
  namespace export *
}

