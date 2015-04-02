::namespace eval ::tao {}

###
# topic: 3d9cc4f6252df40c5fd760ea4ba86f13
# title: Manage the module stack
# description:
#    While the module stack does not impact normal operations within Tao
#    maintaining it allow Tao to populate the "package" field in the tao::db
#    [example {
#    ::tao::module push myPackage
#    ::tao::load_path $dir
#    ::tao::module pop
#    }]
# darglist: [arg operation] [opt [arg module]]
###
proc ::tao::module {cmd args} {
  ::variable moduleStack
  ::variable module
  
  switch $cmd {
    push {
      set module [lindex $args 0]
      lappend moduleStack $module
      return $module
    }
    pop {
      set priormodule      [lindex $moduleStack end]
      set moduleStack [lrange $moduleStack 0 end-1]
      set module [lindex $moduleStack end]
      return $priormodule
    }
    peek {
      set module      [lindex $moduleStack end]
      return $module
    }
    default {
      error "Invalid command \"$cmd\". Valid: peek, pop, push"
    }
  }
}

::tao::module push core

