#!/bin/sh
# \
exec /proj/tcl/install/5.x-sparc/bin/tclsh8.0 "$0" ${1+"$@"}

puts "Content-Type: text/html"
puts "Location: http://$env(SERVER_NAME):$env(SERVER_PORT)/"
puts ""
puts "<title>Redirect</title>"
puts "You should get a redirect"
exit 0
