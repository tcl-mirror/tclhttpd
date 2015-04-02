###
# topic: 62313463-3530-3535-3337-3237343930343
###

foreach varname {
  ::tao::info::class
  ::tao::info::object
} {
  if {![info exists $varname]} {
    set $varname {}
  }
}


if {[info command ::tao::db] eq {}} {
  package require sqlite3
  sqlite3 ::tao::db :memory:
  # Build the schema
  ::tao::db function string_match {string match}
  
  ::tao::db eval {
create table class (
  name string primary key,
  package string,
  superclass list default '::tao::moac',
  regenerate integer default 0
);

create table class_property (
  class string references class,
  type  string default const,
  property string,
  dict text,
  primary key (class,type,property) on conflict replace
);

create table class_ensemble (
  class string references class,
  ensemble string,
  method string,
  arglist string,
  body text,
  primary key (class,ensemble,method) on conflict replace
);

create table class_typemethod (
  class string references class,
  method string,
  arglist string,
  body text,
  primary key (class,method) on conflict replace
);

create table class_alias (
  cname string references class,
  alias string references class
);

create table class_ancestor (
  class string references class,
  direct integer default 0,
  seq integer,
  ancestor string references class,
  primary key (class,ancestor) on conflict ignore
);

create table object (
  name string primary key,
  package string,
  regen integer default 0
);

create table object_alias (
  cname string references object,
  alias string references object
);

create table object_bind (
  object string references object,
  event  string,
  script blob,
  primary key (object,event) on conflict replace
);

create table object_schedule (
  object string references object,
  event  string,
  time   integer,
  eventorder  integer default 0,
  script string,
  primary key (object,event) on conflict replace
);

create table object_subscribers (
  sender   string references object,
  receiver string references object,
  event string,
  primary key (sender,receiver,event) on conflict ignore
);
  }
}

###
# topic: b14c505537274904578340ec1bc12af1
###
namespace eval ::tao {
  variable trace 0
}

