#!/usr/local/bin/tclsh8.2

package require http 2.0

set url [lindex $argv 0]
if {[string length $url] == 0} {
    set server http://localhost:8015/debug/echo
}

# Construct a vast amount of post data to try and choke the server.

set i 0
set sep ""
while {$i < 10000} {
    append bigpost "${sep}name$i=value$i"
    set sep &
    incr i
}

puts "Posting [string length $bigpost] bytes to $url"
puts [time {set token [http::geturl $url -query $bigpost]}]
http::wait $token
set X [http::data $token]
puts "Got [string length $X] bytes\n[string range $X 0 64]..."
http::cleanup $token
