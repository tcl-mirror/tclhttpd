#!/bin/sh
# \
exec tclsh8.0 "$0" ${1+"$@"}

puts "Content-Type: text/html"
puts ""
puts "<title>The environment</title>"

if {[catch {
    puts [info hostname]<p>
    close [socket 127.0.0.1 5000]
    source prodebug.tcl
    if {![debugger_init 127.0.0.1 5000]} {
	puts "debugger_init failed"
	puts "<pre>$errorInfo</pre>"
    } else {
	puts "Contacted the debugger"
    }
} err]} {
    puts "<pre>$errorInfo</pre>"
}

debugger_eval {
    puts "<H1>The environment</h1>"
    puts <table>
    foreach name [lsort [array names env]] {
	    puts "<tr><td>$name</td><td>$env($name)</td></tr>"
    }
    puts </table>
}
exit 0
