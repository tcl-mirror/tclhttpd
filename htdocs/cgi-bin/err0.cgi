#!/bin/sh
# This nasty script exits without doing anything
# \
exec tclsh "$0" ${1+"$@"}

exit 0
