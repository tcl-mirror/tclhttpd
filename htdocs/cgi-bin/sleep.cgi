#!/bin/sh
# \
exec /proj/tcl/install/5.x-sparc/bin/tclsh8.0 "$0" ${1+"$@"}

set text [exec sleep 5; exec ls]
puts $text

close [open /tmp/something w]

exit 0
