package require Mk4tcl
package provide bugdb 1.0

namespace eval bugdb {
    namespace export *
}

proc bugdb::insert {Application OS Priority Assigned Summary Description} {
    # set date
    set date [clock format [clock seconds] ]

    # Open the db
    mk::file open bugdb ../sampleapp/bugdb/bugdb.mk

    set result [catch {mk::row append bugdb.bugs Application "$Application" OS "$OS" \
    Priority "$Priority" Assigned "$Assigned" Summary "$Summary" \
    Description "$Description" date "$date"} msg]

    mk::file commit bugdb

    # Close the db
    mk::file close bugdb

    return $result
}
