#!/bin/sh
# This nasty script exits without doing anything
# \
exec tclsh8.0 "$0" ${1+"$@"}

exit 0
