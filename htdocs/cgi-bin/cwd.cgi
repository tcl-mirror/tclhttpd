#!/bin/sh
# This returns the current working directory
# \
exec tclsh "$0" ${1+"$@"}

puts "Content-Type: text/plain\n"

puts "Directory is [pwd]"
