#!/bin/sh
# This nasty script exits without doing anything
# \
exec /usr/local/bin/tclsh8.0 "$0" ${1+"$@"}

exit 0
