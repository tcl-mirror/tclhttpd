###
# Base classes for Model/View/Controller architecture
###

###
# topic: 71b9a2bf1f9b9e1c8b1e06ceaa088b1d
# description:
#    This class implements a common data store used by
#    a model view controller
###
tao::class tao.mvcstore {

}

###
# topic: f9279c5be057cc75b1f1fd3bd4ee3052
###
tao::class tao.model {

}

###
# topic: 2927c0b0fc54227b3538f26e3bd0323b
###
tao::class tao.view {

}

###
# topic: 2d337edf2d1b9042d4ee2510fcc4c99d
###
tao::class tao.controller {
  
  variable mode_stack {}
  variable modes {}
  variable clearing 0

  property default_context {
    class action
    button {}
    main-script {my actionstack clear}
    exit-script {}
    push-script {}
    appswitch-script {}
    popups 1
    cursor arrow
    force_2d 1
    usermode 0
    icon {}
    auto-pop 0
    edit-ok  0
    interactive 0
    modal 0
  }

  signal busy {
    apply_action {my action busy}
    triggers {idle}
  }
  signal idle {
    apply_action {my action idle}
    follows  *
    triggers {}
  }

  ###
  # topic: b749283c69423a3823ff4a9c5ea54a0a
  # description:
  #    Code to run when the application is about to enter a
  #    busy phase
  ###
  method action::busy {} {}

  ###
  # topic: e7b6d7ade002fab7c871236e94d09ff5
  # description: Commands to run when the system ceases to be busy
  ###
  method action::idle {} {}

  ###
  # topic: 22e8612cf1155540ae8463e250978fe6
  # description:
  #    Action to perform at the top of every "peek"
  #    onto the stack
  ###
  method action::mode_peek {
  }

  ###
  # topic: 1906474f86290ff6391a4eb07fa2f7e3
  # description:
  #    Action to perform when a mode is popped off
  #    the stack/exited
  ###
  method action::mode_pop {
  }

  ###
  # topic: 780582fa0c41dcea48ac25c476c15604
  # title: method to execute when we enter the mode from another mode
  # description:
  #    Action to perform when a mode is pushed onto
  #    the stack/entered
  ###
  method action::mode_push {
  }

  ###
  # topic: 849976e96911e4a595d479a45c4c2ec2
  ###
  method action::stack_cleared {
  }

  ###
  # topic: 877b7f2efda12d0e9643afab6090b145
  ###
  method actionstack::clear {} {
    my lock create [self method].$method
    set cleared 0
    variable mode_stack
    while {[llength $mode_stack] > 0} {
      incr cleared
      if {[catch {my actionstack pop} err options]} {
        my action mode_peek
        return -options $options $err
      }
    }
    set mode_stack {}
    my action mode_peek
    if { $cleared } {
      my signal  layer_update
    }
    my lock remove [self method].$method
  }

  ###
  # topic: 2d1fac13797eacfd48cdb8e87462565b
  ###
  method actionstack::define {name settings} {
    my variable modes organs
    if {![info exists modes]} {
      set modes {}
    }
    if {![dict exists $modes $name]} {
      set context [my property default_context]
    } else {
      set context [dict get $modes $name]
    }
    foreach {var val} $settings {
      dict set context $var $val
    }
    dict set modes $name $context
    return $name
  }

  ###
  # topic: 715f11d7322b94a080cc657d2fd02d7f
  # description:
  #    A varient of action that clears the stack and establishes
  #    new base-behaviors. Used to implement the different "modes"
  #    in the visualization (i.e. runmode, playback, etc)
  ###
  method actionstack::morph newclass {
    ###
    # Tell runmode to cease
    ###
    my variable currentclass
    my lock create [self method].$method
    my actionstack clear
    if { [get currentclass] eq $newclass } {
      return
    }
    ###
    # After we have cleared the stack, destroy layers
    # we are not using and add layers that we are
    ###
    global g simconfig
    my action mode_pop
    my morph $newclass
    my activate_layers

    set currentclass $newclass
    my action mode_push [list prev_class $currentclass class $newclass]
    ###
    # Publish that we have changed modes
    ###
    my event generate mode_change prev_class $currentclass class $newclass
    my action mode_peek
    my lock remove [self method].$method
  }

  ###
  # topic: e2a03175995d1ba6e4f9e1224cbbb6cd
  ###
  method actionstack::peek {} {
    my lock create [self method].$method
    my action mode_peek
    my variable mode_stack organs
    if {[llength $mode_stack]==0} {
      my action mode_peek      

      set context [my property default_context]
      set doPop 0
      set force_interactive 1
    } else {
      set context [lindex [get mode_stack] end]
      set doPop 0
      set force_interactive 0
    }
    set code [catch {
      dict with organs {}
      dict with context {}
      my popups_enabled ${popups}
      my cursor $cursor
      my action icon $icon
      if { $button != {} } {
        catch {$button configure -state pressed}
      }
      eval ${main-script}
      if { ${auto-pop} } {
        set doPop 1
      }
    } result returnInfo]
    if { $code ni {0 2} } {      
      set ::errorInfo [list Evaluating object [self] context $context]\n${::errorInfo}
      catch {my actionstack pop}
      return {*}${returnInfo} $result
    }
    if { $doPop } {
      my actionstack pop
    }
    my lock remove [self method].$method
    if {$force_interactive || $interactive} {
      my Signal_pipeline
    }
  }

  ###
  # topic: 312260fae2812d18bdb57fbbe24f7771
  ###
  method actionstack::pop {} {
    my lock create [self method].$method
    my variable mode_stack organs
    set context [lindex $mode_stack end]
    if { $context ne {} } {
      if {![dict get $context usermode]} {
        set mode_stack [lrange $mode_stack 0 end-1]
        dict with organs {}
        dict with context {}
        if [catch ${exit-script} result returnInfo] {
          set ::errorInfo [list Evaluating object [self] context $context]\n${::errorInfo}
          return {*}${returnInfo} $result
        }
      }
    }
    my lock remove [self method].$method
    my actionstack peek
  }

  ###
  # topic: 6e52f9b7b20156b81348133e3c860e8f
  ###
  method actionstack::push {mode {inputcontext {}}} {
    my variable mode_stack modes organs
    my action busy
    my lock create [self method].$method
    set script {}
    ###
    # Load our organs as the local context
    ###
    set context [my property default_context]
    if {[dict exists $modes $mode]} {
      foreach {var val} [dict get $modes $mode] {
        dict set context $var $val
      }
    }
    foreach {var val} $inputcontext {
      dict set context $var $val
    }
    dict set context mode $mode
    dict set modes $mode $context
    set stack_clear 0
    
    if {[dict exists $context exclusive]} {
      ###
      # If we have certain modes that are mutually exclusive on
      # the task stack, clear the stack
      ###
      set exclusive [dict get  $context exclusive]
      set top [lindex $mode_stack end]
      if {[dict exists $top mode]} {
        if {[dict get $top mode] in $exclusive} {
          set stack_clear 1
        }
      }
    }
    ####
    # Modal actions want to be the
    # top thing on the stack
    # so cancel anything else going on
    ###
    if {[dict get $context modal]} {
      set stack_clear 1
    }

    if { $stack_clear } {
      my actionstack clear
    }
    lappend mode_stack $context
    dict with organs {}
    dict with context {}
    if [catch ${push-script} result returnInfo] {
      set ::errorInfo [list Evaluating object [self] context $context]\n${::errorInfo}
      return {*}${returnInfo} $result
    }
    my lock remove [self method].$method
    my actionstack peek
  }

  ###
  # topic: 3aaf2e553ea49a156469847f2a9e60f0
  ###
  method configurelist_triggers dictargs {
    set dat [my property option dict]
    ###
    # Apply normal inputs
    ###
    my lock create configure
    foreach {field val} $dictargs {
      my Option_set $field $val
    }
    ###
    # Generate all signals
    ###
    foreach {field val} $dictargs {
      set signal [dict getnull $dat $field signal]
      if {$signal ne {}} {
        my signal  $signal
      }
    }
    my Prefs_Store $dictargs
    my lock remove configure
    foreach {field val} $dictargs {
      set signal [dict getnull $dat $field signal]
      if {$signal ne {}} {
        my event generate {*}$signal [list value $val]
      }
    }
  }
}

