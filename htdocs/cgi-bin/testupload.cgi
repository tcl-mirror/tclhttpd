#!/bin/sh
# \
exec tclsh8.3 "$0"
#
puts "Content-Type: text/html"
puts ""

puts "<h2>Environment</h2>"
puts "<table>"
foreach {n v} [array get env] {
    puts "<tr><td>$n</td><td>$v</td></tr>"
}
puts "</table>"

puts <pre>
fconfigure stdin -translation binary
puts [read stdin $env(CONTENT_LENGTH)]
puts </pre>
