#!/bin/sh
# \
exec tclsh "$0" ${1+"$@"}

if {[catch {
    package require ncgi


    ncgi::redirect http://$env(SERVER_NAME):$env(SERVER_PORT)/
    exit 0
}]} {
    puts "Content-Type: text/html\n"
    puts "<h1>CGI Error</h1>"
    puts "<pre>$errorInfo</pre>"
}
