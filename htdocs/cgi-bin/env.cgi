#!/bin/sh
# \
exec tclsh8.0 "$0" ${1+"$@"}

#close [open /tmp/iwashere w]

puts "Content-Type: text/html"
puts ""
puts "<title>The environment</title>"
puts "<H1>The environment</h1>"
puts <table>
foreach name [lsort [array names env]] {
	puts "<tr><td>$name</td><td>$env($name)</td></tr>"
}
puts </table>
exit 0
