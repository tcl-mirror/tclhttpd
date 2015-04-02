###
# This file implements the Tao event manager
###

::namespace eval ::tao {}

::namespace eval ::tao::event {}

###
# topic: 2097c1149d50b67b94ea09f0bcad9e5c
# description: Subscribe an object to events of type <b>event</b>
###
proc ::tao::event::bind {self event args} {
  if {![llength $args]} {
    return [::tao::db one {select script from object_bind where object=:self and event=:event}]
  }
  set script [lindex $args 0]
  if { $script eq {} } {
    ::tao::db eval {delete from object_bind where object=:self and event=:event}
  } else {
    ::tao::db eval {
insert or ignore into object(name) VALUES (:self);
insert or replace into object_bind (object,event,script) VALUES (:self,:event,:script);
}
  }
}

###
# topic: f2853d380a732845610e40375bcdbe0f
# description: Cancel a scheduled event
###
proc ::tao::event::cancel {self {task *}} {
  variable timer_event
  foreach {id event} [array get timer_event $self:$task] {
    ::after cancel $event
    set timer_event($id) {}
  }
}

###
# topic: 8ec32f6b6ba78eaf980524f8dec55b49
# description:
#    Generate an event
#    Adds a subscription mechanism for objects
#    to see who has recieved this event and prevent
#    spamming or infinite recursion
###
proc ::tao::event::generate {self event args} {
  set dictargs [::tao::args_to_options {*}$args]

  set info $dictargs
  set strict 0
  set debug 0
  set sender $self
  dict with dictargs {}
  dict set info id     [::tao::event::nextid]
  dict set info origin $self
  dict set info sender $sender
  dict set info rcpt   {}
  
  
  foreach who [Notification_list $self $event] {
    catch {::tao::event::notify $who $self $event $info}
  }
}

###
# topic: 891289a24b8cc52b6c228f6edb169959
# title: Return a unique event handle
###
proc ::tao::event::nextid {} {
  return "event#[format %0.8x [incr ::tao::event_count]]"
}

###
# topic: 1e53e8405b4631aec17f98b3e8a5d6a4
# description:
#    Called recursively to produce a list of
#    who recieves notifications
###
proc ::tao::event::Notification_list {self event {stackvar {}}} {
  if { $stackvar ne {} } {
    upvar 1 $stackvar stack
  } else {
    set stack {}
  }
  if {$self in $stack} {
    return {}
  }
  lappend stack $self

  ::tao::db eval {select receiver from object_subscribers where string_match(sender,:self) and string_match(event,:event)} {
    ::tao::db eval {select name as rcpt from object where string_match(name,:receiver)} {
      Notification_list $rcpt $event stack
    }
  }
  return $stack
}

###
# topic: b4b12f6aed69f74529be10966afd81da
###
proc ::tao::event::notify {rcpt sender event eventinfo} {
  if {$::tao::trace} {
    puts [list event notify rcpt $rcpt sender $sender event $event info $eventinfo]
  }
  $rcpt notify $event $sender $eventinfo
}

###
# topic: 829c89bda736aed1c16bb0c570037088
###
proc ::tao::event::process {self handle script} {
  variable timer_event
  array unset timer_event $self:$handle
  set err [catch {uplevel #0 $script} result]
  if $err {
    puts "BGError: $self $handle $script
ERR: $result"
  }
}

###
# topic: a6e4eebefcd2cec57ee4f0d8c10c92c0
###
proc ::tao::event::publish {self who event} {
  ::tao::db eval {
insert or ignore into object(name) VALUES (:self);
insert or replace into object_subscribers (sender,receiver,event) VALUES (:self,:who,:event);
}
}

###
# topic: eba686cffe18cd141ac9b4accfc634bb
# description: Schedule an event to occur later
###
proc ::tao::event::schedule {self handle interval script} {
  variable timer_event

  if {$::tao::trace} {
    puts [list $self schedule $handle $interval]
  }
  if {[info exists timer_event($self:$handle)]} {
    ::after cancel $timer_event($self:$handle)
  }
  set timer_event($self:$handle) [::after $interval [list ::tao::event::process $self $handle $script]]
}

###
# topic: 63d680db51c1a3a04c2a038b8f9747d0
###
proc ::tao::event::signal {self event} {
  
}

###
# topic: e64cff024027ee93403edddd5dd9fdde
###
proc ::tao::event::subscribe {self who event} {
  ::tao::db eval {
insert or ignore into object(name) VALUES (:self);
insert or replace into object_subscribers (receiver,sender,event) VALUES (:self,:who,:event);
}
}

###
# topic: 177acc5c440c615437dd02cba0ab778c
###
proc ::tao::event::unpublish {self args} {
  switch {[llength $args]} {
    0 {
      ::tao::db eval {delete from object_subscribers where sender=:self}
    }
    1 {
      set event [lindex $args 0]
      ::tao::db eval {delete from object_subscribers where sender=:self and string_match(event,:event)=1}
    }
  }
}

###
# topic: 5f74cfd01735fb1a90705a5f74f6cd8f
###
proc ::tao::event::unsubscribe {self args} {
  switch {[llength $args]} {
    0 {
      ::tao::db eval {delete from object_subscribers where receiver=:self}
    }
    1 {
      set event [lindex $args 0]
      ::tao::db eval {delete from object_subscribers where receiver=:self and string_match(event,:event)=1}
    }
  }
}

###
# topic: 37e7bd0be3ca7297996da2abdf5a85c7
# description: The event manager for Tao
###
namespace eval ::tao::event {
  variable nextevent {}
  variable nexteventtime 0
}

