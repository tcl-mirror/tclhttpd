#!/bin/sh
# This nasty script never generates output
# \
exec /usr/local/bin/tclsh8.0 "$0" ${1+"$@"}

while (1) {
    after 10000
}
