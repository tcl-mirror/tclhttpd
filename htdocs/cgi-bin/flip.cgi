#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}

if {[catch {
    package require ncgi
    package require html

    set bit [expr [clock clicks] & 1]
    ncgi::header

    puts [html::head "Coin Flip"]
    puts [html::h1 "Coin Flip"]
    if {$bit} {
	puts heads
    } else {
	puts tails
    }
    exit 0
}]} {
    puts "Content-Type: text/html\n"
    puts "<h1>CGI Error</h1>"
    puts "<pre>$errorInfo</pre>"
}
