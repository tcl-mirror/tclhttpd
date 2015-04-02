package provide tao-sqlite 0.3

package require tao
package require sqlite3
package require sha1 2
::tao::module push tao-sqlite

::namespace eval ::taodb {}

::tao::load_path [::tao::script_path] {
  procs.tcl connection.tcl oosqlite.tcl module.tcl
}
::tao::module pop

