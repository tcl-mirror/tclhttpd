#!/bin/sh
# \
exec tclsh8.0 "$0" ${1+"$@"}

source [file join [file dirname [info script]] cgilib.tcl]

set bit [expr [clock clicks] & 1]
Cgi_Header Hello

H1 "Coin Flip"
if {$bit} {
    puts heads
} else {
    puts tails
}
exit 0

