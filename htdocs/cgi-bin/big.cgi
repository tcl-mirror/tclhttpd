#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}

set path [file join [file dirname [file dirname [info script]]] images pwrdLogo200.gif]
set in [open $path]

puts "Content-Type: image/gif"
puts "Content-Length: [file size $path]"
puts ""
fconfigure $in -translation binary
fconfigure stdout -translation binary

# Delay to simulate slow CGI
after 1000
fcopy $in stdout
close $in
exit 0
