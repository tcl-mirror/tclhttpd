###
# topic: a499aa36ee878a743ac8a269bfd3a1e3
# description: Sqlite based storage for application settings
###
tao::class taodb::prefdb {
  superclass taodb::module.sqlite

  property create_sql {
create table prefs (
  field string,
  value string,
  mtime integer,
  primary key (field)
);
create table history (
  field string,
  value string,
  mtime integer,
  primary key (field,value) on conflict replace
);
create index historyMtime on history (mtime);
}

  ###
  # topic: bd83ad1abbfc4516fd6adc5d6ddfd553
  ###
  method create_temp_tables {} {
create table property (
  node  string,
  field string,
  value string,
  primary key (node,field) on conflict replace
);
  }
}

