
if {[info command ::tao::metaclass] eq {}} {
  oo::class create ::tao::metaclass {
    superclass ::oo::class
    
    destructor {
      ::tao::class_destroy [self]
    }
  }
}

###
# topic: bb7bd8d93b61e5163b84e16341de3a35
# title: Mother of all Classes
# description:
#    Base class used to define a global
#    template of expected behaviors
###
tao::class tao::moac {
  aliases moac
  
  variable signals_pending {}
  variable signals_processed {}
  variable organs {}
  # Sets an active lock that will be
  # erased by a lock remove added to tail
  # of all tao constructors
  variable ActiveLocks constructor
  option trace {
    widget boolean
    default 0
  }
  option_class variable {
    widget entry
    set-command {my Variable_set %field% %value%}
    get-command {my Variable_get %field%}
  }
  option_class organ {
    widget label
    set-command {my Option_graft %field% %value%}
    get-command {my organ %field%}
  }
  option_class property {
    widget label
    default-command {my property %field%}
  }

  property options_strict 0

  constructor args {
    my configurelist [::tao::args_to_options {*}$args]
    my initialize
  }

  destructor {}

  ###
  # topic: fa52b5fa66bccb878ae6c4fe88f471a3
  # description: Indicate to the user that the program is processing
  ###
  method action::busy {}

  ###
  # topic: 97d5cd58316988a2733c7ac2ad19735b
  # description: Commands to run when the system releases the gui
  ###
  method action::idle {}

  ###
  # topic: 03e3b8c1558a8153bc307fc098696d14
  ###
  method action::morph_enter {} {}

  ###
  # topic: f54fc2f9dfcba2ff0e888469b3b3ba27
  ###
  method action::morph_leave {} {}

  ###
  # topic: 7097c7ae9136bef863f89edddc384f60
  ###
  method action::pipeline_busy {} {}

  ###
  # topic: d971de215cd4ce584813fdaa09ae6819
  # description: Commands to run when the system releases the locks
  ###
  method action::pipeline_idle {} {}

  ###
  # topic: 86a1b968cea8d439df87585afdbdaadb
  ###
  method cget {field {default {}}} {
    my variable config
    set field [string trimleft $field -]
    set dat [my property option dict]
  
    if {[my property options_strict] && ![dict exists $dat $field]} {
      error "Invalid option -$field. Valid: [dict keys $dat]"
    }
    set info [dict getnull $dat $field]    
    if {$default eq "default"} {
      set getcmd [dict getnull $info default-command]
      if {$getcmd ne {}} {
        return [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
      } else {
        return [dict getnull $info default]
      }
    }
    if {[dict exists $dat $field]} {
      set getcmd [dict getnull $info get-command]
      if {$getcmd ne {}} {
        return [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
      }
      if {![dict exists $config $field]} {
        set getcmd [dict getnull $info default-command]
        if {$getcmd ne {}} {
          dict set config $field [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
        } else {
          dict set config $field [dict getnull $info default]
        }
      }
      if {$default eq "varname"} {
        set varname [my varname visconfig]
        set ${varname}($field) [dict get $config $field]
        return "${varname}($field)"
      }
      return [dict get $config $field]
    }
    if {[dict exists $config $field]} {
      return [dict get $config $field]
    }
    return [my property $field]
  }

  ###
  # topic: 835853285c2acbbaaa3eb1abb5d1dbe9
  ###
  method code {} {
    return [namespace code {self}]
  }

  ###
  # topic: 73e2566466b836cc4535f1a437c391b0
  ###
  method configure args {
    # Will be removed at the end of "configurelist_triggers"
    set dictargs [::tao::args_to_options {*}$args]
    if {[llength $dictargs] == 1} {
      return [my cget [lindex $dictargs 0]]
    }
    my configurelist $dictargs
    my configurelist_triggers $dictargs
  }

  ###
  # topic: dc9fba12ec23a3ad000c66aea17135a5
  ###
  method configurelist dictargs {
    my variable config
    set dat [my property option dict]
    if {[my property options_strict]} {
      foreach {field val} $dictargs {
        if {![dict exists $dat $field]} {
          error "Invalid option $field. Valid: [dict keys $dat]"
        }
      }
    }
    ###
    # Validate all inputs
    ###
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field validate-command]
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      }
    }
    ###
    # Apply all inputs with special rules
    ###
    foreach {field val} $dictargs {
      set script [dict getnull $dat $field set-command]
      if {$script ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $val] %self% [namespace which my]] $script]
      } else {
        dict set config $field $val
      }
    }
  }

  ###
  # topic: 543c936485189593f0b9ed79b5d5f2c0
  ###
  method configurelist_triggers dictargs {
    set dat [my property option dict]
    # Add a lock to prevent signals from
    # spawning signals
    my lock create configure
    ###
    # Apply normal inputs
    ###
    foreach {field val} $dictargs {
      if [catch {
        if {[dict exists $dat $field signal]} {
          my signal {*}[dict get $dat $field signal]
        }
        my Option_set $field $val
      } err] {
        puts [list [self] bg configure error: field $field val $val error $err]
      }
    }
    my Prefs_Store $dictargs
    my lock remove configure
  }

  ###
  # topic: 7b7c4a1ea317ff9e699c875353cf00cf
  ###
  method debugOut string {}

  ###
  # topic: 20b4a97617b2b969b96997e7b241a98a
  ###
  method event {submethod args} {
    ::tao::event::$submethod [self] {*}$args
  }

  ###
  # topic: d7787c21bbba4fbc8cc347fa6f0b1bc5
  ###
  method forward {method args} {
    oo::objdefine [self] forward $method {*}$args
  }

  ###
  # topic: 87ba9c0905dbadcb68abe425339caddc
  ###
  method get {{field {}}} {
    if { $field == {} } {
      set result {}
      foreach f [::info object vars [self]] {
        my variable $f
        if {[array exists $f]} {
          dict set result @$f [::array get $f]
        } else {
          dict set result $f [set $f]
        }
      }
      return $result
    }
    my variable $field
    if {[array exists $field]} {
      return [::array get $field]
    }
    if {[info exists $field]} {
      return [set $field]
    }
    return {}
  }

  ###
  # topic: d0bf3b83fdbef6d41b5585eb034088da
  ###
  method getVarname field {
    return [my varname $field]
  }

  ###
  # topic: 9afd530cdd4fa83b793dd66f59f707af
  ###
  method graft args {
    my variable organs
    if {[llength $args] == 1} {
      error "Need two arguments"
    }
    set object {}
    foreach {stub object} $args {
      set stub [string trimleft $stub /]
      dict set organs $stub $object
      oo::objdefine [self] forward ${stub} $object
      oo::objdefine [self] forward <${stub}> $object
      oo::objdefine [self] export <${stub}>
    }
    return $object
  }

  ###
  # topic: 4369b15a85b8dc3453ee6af2902bd383
  # description:
  #    Called during the constructor to
  #    set up all local variables and data
  #    structures. It is a seperate method
  #    to ensure inheritence chains predictably
  #    and also to keep us from having to pass
  #    along the constructor's arguments
  ###
  method initialize {} {}

  ###
  # topic: 3c4893b65a1c79b2549b9ee88f23c9e3
  # description:
  #    Provide a default value for all options and
  #    publically declared variables, and locks the
  #    pipeline mutex to prevent signal processing
  #    while the contructor is still running.
  #    Note, by default an odie object will ignore
  #    signals until a later call to <i>my lock remove pipeline</i>
  ###
  method InitializePublic {} {
    my variable config
    if {![info exists config]} {
      set config {}
    }
    set dat [my property option dict]
    foreach {var info} $dat {
      if {[dict exists $info set-command]} {
        if {[catch {my cget $var} value]} {
          dict set config $var [my cget $var default]
        } else {
          if { $value eq {} } {
            dict set config $var [my cget $var default]
          }
        }
      }
      if {![dict exists $config $var]} {
        dict set config $var [my cget $var default]
      }
    }
    foreach {var info} [my property variable dict] {
      if { $var eq "config" } continue
      my variable $var
      if {![info exists $var]} {
        if {[dict exists $info default]} {
          set $var [dict get $info default]
        } else {
          set $var {}
        }
      }
    }
    foreach {var info} [my property array dict] {
      if { $var eq "config" } continue
      my variable $var
      if {![info exists $var]} {
        if {[dict exists $info default]} {
          array set $var [dict get $info default]
        } else {
          array set $var {}
        }
      }
    }
    my configurelist [my Prefs_Load]
  }

  ###
  # topic: 6c9e9e67ccd608d1983bbebcd81f2fd3
  ###
  method lock::active {} {
    my variable ActiveLocks
    return $ActiveLocks
  }

  ###
  # topic: 86d39889df168ace883017cac2de3b61
  ###
  method lock::create args {
    my variable ActiveLocks
    set result 0
    foreach lock $args {
      if { $lock in $ActiveLocks } {
        set result 1
      } else {
        lappend ActiveLocks $lock
      }
    }
    return $result
  }

  ###
  # topic: 6d8562be9185ac4990c3128a5a6aaac8
  ###
  method lock::peek args {
    my variable ActiveLocks
    set result 0
    foreach lock $args {
      if { $lock in $ActiveLocks } {
        set result 1
      }
    }
    return $result
  }

  ###
  # topic: 8429bd3d95cbe42db11fa9d78073ed87
  ###
  method lock::remove args {
    my variable ActiveLocks
    if {![llength $ActiveLocks]} {
      return 0
    }
    set oldlist $ActiveLocks
    set ActiveLocks {}
    foreach item $oldlist {
      if {$item ni $args} { lappend ActiveLocks $item }
    }
    if {![llength $ActiveLocks]} {
      my lock remove_all
      return 1
    }
    return 0
  }

  ###
  # topic: 00210688cea68a175df35ff2c25ce5dd
  # description: Force-Removes all locks
  ###
  method lock::remove_all {} {
    my variable ActiveLocks
    set ActiveLocks {}
    my Signal_pipeline
  }

  ###
  # topic: 75af8a0e6c55a9619ee87698b08bd328
  ###
  method message::error {error errorInfo} {
    puts "Error\n$error\n***\n$::errorInfo"
    return -code 1 $error -errorinfo $errorInfo
  }

  ###
  # topic: d15a85525b1f7151cd808e592bc09fed
  ###
  method morph newclass {
    my lock create morph
    set class [string trimleft [info object class [self]]]
    set newclass [string trimleft $newclass :]
    if {[info command ::$newclass] eq {}} {
      error "Class $newclass does not exist"
    }
    if { $class ne $newclass } {
      my action morph_leave
      oo::objdefine [self] class ::${newclass}
      my variable config
      set savestate $config
      my InitializePublic
      my configurelist $savestate
      my action morph_enter
    }
    my lock remove morph
  }

  ###
  # topic: 87c7b53c998e1f15c46b6a2fd187ef81
  ###
  method mutex::down flag {
    my variable mutex
    if {![info exists mutex($flag)]} {
      set mutex($flag) 0
    }
    set value $mutex($flag)
    set mutex($flag) 0
    return $value
  }

  ###
  # topic: 958a56b4c9598f3988955d7606e8c049
  ###
  method mutex::peek flag {
    my variable mutex
    if {![info exists mutex($flag)]} {
      set mutex($flag) 0
    }
    return $mutex($flag)
  }

  ###
  # topic: 1adff94c1cc08f5286b11c97480b3546
  ###
  method mutex::up flag {
    my variable mutex
    if {![info exists mutex($flag)]} {
      set mutex($flag) 0
    }
    if {[set mutex($flag)] > 0} {
      return 1
    }
    set mutex($flag) 1
    return 0
  }

  ###
  # topic: 3277490dddb5b19f42faaaaa50026f64
  # description: Provide a quiet null handler for events
  ###
  method notify::default {sender dictargs} {}

  ###
  # topic: f1ce03ba2aab515d7d7c36ce04e49eda
  ###
  method Option_get::default {} {
    my variable $method
    if {[info exists $method]} {
      return [set $method]
    }
    return {}
  }

  ###
  # topic: 092e79383ef394de41de7a4143beef2b
  ###
  method Option_graft {organ pointer} {
    my variable config
    if { $pointer ne {} } {
      dict set config $organ $pointer
      my graft $organ $pointer
    }
  }

  ###
  # topic: 3749709452836a574ce3dd8165b1308c
  ###
  method Option_noop args {
  }

  ###
  # topic: 4fa8bc688ade4893c0083d96c9e1ddfc
  # description: Default handler for options
  ###
  method Option_set::default newvalue {
    my variable $method
    if {[info exists $method]} {
      set $method $newvalue
    }
  }

  ###
  # topic: 57e093ecd48756c19e14068cad2e6856
  ###
  method OptionsMirrored organ {
    set result {}
    foreach {opt info} [my property option dict] {
      if {$organ in [dict getnull $info mirror]} {
        lappend result -$opt [my cget $opt]
      }
    }
    return $result
  }

  ###
  # topic: f867ee5408660c0296d731cda02b2bf8
  ###
  method organ {{stub all}} {
    my variable organs
    if {![info exists organs]} {
      return {}
    }
    if { $stub eq "all" } {
      return $organs
    }
    return [dict getnull $organs $stub]
  }

  ###
  # topic: fca634e0193df7049d096dd43dd3c417
  # title: Load persistant preferences
  ###
  method Prefs_Load {} {}

  ###
  # topic: e7f90dcfee554639cbf35b695827421a
  # title: Store persistant preferences
  ###
  method Prefs_Store dictargs {}

  ###
  # topic: 03c9ac58d726fe271c331c513f05b3a9
  ###
  method private {method args} {
    return [my $method {*}$args]
  }

  ###
  # topic: 30668ecb1349a981d393d705f5ffe2e0
  ###
  method proxy who {
    return [$who code]
  }

  ###
  # topic: b57ca4f29c6f69e4167176e13ced14ec
  ###
  method put args {
    if { [llength $args] == 1 } {
      set args [lindex $args 0]
    }
    foreach {key val} [::tao::args_to_dict {*}$args] {
      string trimleft $key -
      my variable $key
      set $key $val
    }
  }

  ###
  # topic: 1fe5a989f9e4334a1052fb4ef99eb7d1
  ###
  method sensai object {
    foreach {stub obj} [$object organ all] {
      my graft $stub $obj
    }
  }

  ###
  # topic: b6214c62683a643102ade2ef21853873
  # description: Does nothing
  ###
  method signal args {
    set rawlist [::tao::args_to_dict {*}$args]
    my variable signals_pending signals_processed
        
    set sigdat [my property signal dict]
    ###
    # Process incoming signals
    ###
    set signalmap $signals_pending
    foreach rawsignal $rawlist {
      ::tao::signal_expand $rawsignal $sigdat signalmap
    }

    set newsignals {}
    foreach signal $signalmap {
      if {$signal in $signals_processed} continue
      if {$signal in $signals_pending} continue
      set action [dict get $sigdat $signal action]
      if {[string length $action]} {
        lappend newsignals $signal
        lappend signals_pending $signal
      }
      set apply_action [dict get $sigdat $signal apply_action]
      if {[string length $apply_action]} {
        eval $apply_action
      }
    }
    if {[llength [my lock active]]} {
      return
    }

    if {("idle" in $rawlist && [llength $signals_pending]) || [llength $newsignals] } {
      set event [my event schedule signal idle [namespace code {my Signal_pipeline}]]
    } else {
      set event {}
    }
    return [list $event $signals_pending]
  }

  ###
  # topic: b9adb42b9e32fca79a9af340144281b6
  ###
  method Signal_pipeline {} {
    if {[my mutex up pipeline]} {
      ###
      # Prevent the pipeline from being entered twice
      ###
      return
    }
    set errlist {}
    set trace [my cget trace]
    my action pipeline_busy
    set sigdat [my property signal dict]
    my variable signals_pending signals_processed
    set order [my property meta signal_order]
    set pass 0
    if {$trace} {
      puts [list [self] [self method] $signals_pending]
    }
    if [catch {
    while {[llength [set signals $signals_pending]]} {
      ###
      # Copy our pending signals and clear out the list
      ###
      set signals_pending {}
      # Ignore mutually exclusive tasks
      set ignored {}
      foreach signal $order {
        if { $signal in $signals && $signal ni $ignored } {
          foreach item [dict get $sigdat $signal excludes] {
            ::ladd ignored $item
          }
        }
      }      
      ###
      # Fire off signals in the order calculated
      ###
      foreach signal $order {
        if { $signal in $signals && $signal ni $ignored } {
          set action [dict get $sigdat $signal action]
        }
      }
      foreach signal $order {
        if { $signal in $signals && $signal ni $ignored } {
          lappend signals_processed $signal
          if {$trace} {
            puts [list $signal [dict get $sigdat $signal action]]
          }
          eval [dict get $sigdat $signal action]
        }
      }
    }
    } err] {
      lappend errlist $err $::errorInfo
    }
    my mutex down pipeline
    my action pipeline_idle
    foreach {err info} $errlist {
      my message error $err $info
    }
    ###
    # If this sequence triggered more sequences
    # schedule our next call
    ###
    set signals_processed {}
  }

  ###
  # topic: 135c91aa5f0344e5a37c31c003f7d7ca
  # title: Generate a path to a subordinate object
  ###
  method SubObject::default {} {
    return [namespace current]::SubObject_generic_$method
  }

  ###
  # topic: 853c3b333a67f543c032852f546556c2
  ###
  method trace {{onoff {}}} {
    my variable trace
    if { $onoff == {} } {
      return $trace
    }
    set trace $onoff
    if { $trace } {
      oo::objdefine [self] method debugOut string {puts [list [my simTime] [self] $string]}
    } else {
      oo::objdefine [self] method debugOut string {}
    }
  }

  ###
  # topic: d70aa45da749a2fe7c1fb9755678322b
  ###
  method Variable_get::default {} {
    my variable $method
    return [get $method]
  }

  ###
  # topic: 02c62587fbec93f8adccc41d201c7c26
  ###
  method Variable_set::default newvalue {
    my variable $method
    set $method $newvalue
  }
}

