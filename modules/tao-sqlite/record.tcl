###
# topic: 49fee6ecf96ef7b3d3ecd7565a047b20
# title: Generic class to process database records
###
tao::class taodb::record {
  superclass
  
  option layer {
    class organ
    description {Object which abstracts access to the underlying storage}
  }
  property variable nodeid {default -1}
  property variable unit   {default {}}  
  property array db_record {}
  property array db_specs  {}

  ###
  # topic: b5cf9de15d1e7c7fead7b5794acb59db
  ###
  method action::delete {} {
    set objid [my objid]
    # Note: we are counting on the layer's node_edit_delete
    # method to call our destructor and/or destroy our window
    my layer db_record_delete $objid
  }

  ###
  # topic: 1d8ca0d3c3b915fadae5f1edb4343833
  ###
  method action::destroy {} {}

  ###
  # topic: fa3fbe68c3a633950547bbe096dd762d
  ###
  method action::save {
    my variable db_record
    set pkey [my <layer> db_record_key [array get db_record]]
    set savedata [array get db_record]
    my <layer> db_record_
  }
}

