#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}

set text [exec sleep 5; exec ls]
puts $text

close [open /tmp/something w]

exit 0
