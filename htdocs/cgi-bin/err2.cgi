#!/bin/sh
# This nasty script generates output, then hangs
# \
exec tclsh8.3 "$0" ${1+"$@"}

puts "Content-Type: text/html"
puts ""
puts [clock format [clock seconds]]<br>
puts "This script is hung<br>"
flush stdout
while (1) {
    after 10000
}
