#!/bin/sh
# This nasty script never generates output
# \
exec tclsh8.0 "$0" ${1+"$@"}

puts "Content-Type: text/plain\n"

puts "Directory is [pwd]"
