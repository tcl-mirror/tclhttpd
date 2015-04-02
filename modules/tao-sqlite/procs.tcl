::namespace eval ::tao {}

###
# topic: 0a19b0bfb98162a8a37c1d3bbfb8bc3d
# description:
#    Because the tcllib version of uuid generate requires
#    network port access (which can be slow), here's a fast
#    and dirty rendition
###
proc ::tao::uuid_generate args {
  if {![llength $args]} {
    set block [list [incr ::tao::nextuuid] {*}$::tao::UUID_Seed]
  } else {
    set block $args
  }
  return [::sha1::sha1 -hex [join $block ""]]
}

###
# topic: ee3ec43cc2cc2c7d6cf9a4ef1c345c19
###
proc ::tao::uuid_short args {
  if {![llength $args]} {
    set block [list [incr ::tao::nextuuid] {*}$::tao::UUID_Seed]
  } else {
    set block $args
  }
  return [string range [::sha1::sha1 -hex [join $block ""]] 0 16]
}

###
# topic: b14c505537274904578340ec1bc12af1
# description:
#    Implementation the uses a compiled in ::md5 implementation
#    commonly used by embedded application developers
###
namespace eval ::tao {
  namespace export *

  ###
  # Cache the bits of the UUID seed that aren't likely to change
  # once the software is loaded, but which can be expensive to
  # generate
  ###
  variable ::tao::UUID_Seed [list [info hostname] [get env(USER)] [get env(user)] [clock format [clock seconds]]]
}


