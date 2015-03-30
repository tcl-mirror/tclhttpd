# This is a shim layer to deal with the inconsistencies
# between md5 1 and md5 2 (grr)

package provide httpd::md5hex 1.0
catch {
    # for some reason pkg_mkIndex barfs on this ... hide it.
    package require md5

    # md5hex always returns a hex version of the md5 hash

    if {[package vcompare [package present md5] 2.0] > -1} {
	# we have md5 v2 - it needs to be told to return hex
	interp alias {} md5hex {} ::md5::md5 -hex --
    } else {
	# we have md5 v1 - it returns hex anyway
	interp alias {} md5hex {} ::md5::md5
    }
}
