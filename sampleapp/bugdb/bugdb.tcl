package require Mk4tcl
package provide bugdb 1.0

namespace eval bugdb {
    namespace export *
}

proc bugdb::insert {Application OS Priority Assigned Summary Description} {
    # set date
    set date [clock format [clock seconds] ]

    # Substitute for characters that break the HTML
    regsub -all {"} $Summary {\&quot;} safe_summary
    regsub -all {"} $Description {\&quot;} safe_description

    # Open the db
    mk::file open bugdb ../sampleapp/bugdb/bugdb.mk

    set result [catch {mk::row append bugdb.bugs Application "$Application" OS "$OS" \
    Priority "$Priority" Assigned "$Assigned" Summary "$safe_summary" \
    Description "$safe_description" date "$date" Status "New"} msg]

    mk::file commit bugdb

    # Close the db
    mk::file close bugdb

    return $result
}

proc bugdb::bug-list {} {

    # Open the db
    mk::file open bugdb ../sampleapp/bugdb/bugdb.mk

    set results {}
    set rows [mk::select bugdb.bugs]

    foreach row $rows {
        
	# Get the contents for that row
	lappend results $row \
	                [mk::get bugdb.bugs!$row date] \
	                [mk::get bugdb.bugs!$row Application] \
	                [mk::get bugdb.bugs!$row OS] \
	                [mk::get bugdb.bugs!$row Priority] \
	                [mk::get bugdb.bugs!$row Summary] \
	                [mk::get bugdb.bugs!$row Assigned]
    }

    # Close the db
    mk::file close bugdb

    return $results
}

proc bugdb::bug-details {bug Application OS Priority Assigned \
Summary Description Date Status Updated} {

    upvar 1 $Application my_application
    upvar 1 $OS my_os
    upvar 1 $Priority my_priority
    upvar 1 $Assigned my_assigned
    upvar 1 $Summary my_summary
    upvar 1 $Description my_description
    upvar 1 $Date my_date
    upvar 1 $Status my_status
    upvar 1 $Updated my_updated

    # Open the db
    mk::file open bugdb ../sampleapp/bugdb/bugdb.mk

    set row [mk::get bugdb.bugs!$bug]

    # Close the db
    mk::file close bugdb

    set my_application [lindex $row 1]
    set my_os [lindex $row 3]
    set my_priority [lindex $row 5]
    set my_assigned [lindex $row 7]
    set my_summary [lindex $row 9]
    set my_description [lindex $row 11]
    set my_date [lindex $row 13]
    set my_status [lindex $row 15]
    set my_updated [lindex $row 17]

    return
}

proc bugdb::update {Bug Status Application OS Priority Assigned Summary Description} {
    # set date for last updated field
    set date_updated [clock format [clock seconds] ]
    
    # Substitute for characters that break the HTML
    regsub -all {"} $Summary {\&quot;} safe_summary
    regsub -all {"} $Description {\&quot;} safe_description

    # Open the db
    mk::file open bugdb ../sampleapp/bugdb/bugdb.mk

    # Update the db
    mk::set bugdb.bugs!$Bug Status "$Status" Application "$Application" \
    OS "$OS" Priority "$Priority" Assigned "$Assigned" Summary "$Summary" \
    Description "$Description" Updated "$date_updated"

    # Close the db
    mk::file close bugdb

    return
}
