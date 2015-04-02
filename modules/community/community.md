*httpd.community* is a decendent of [httpd.taourl](wiki?taourl). It adds an sqlite based user, group, and access control system. It is implemented in [community.tcl](finfo?name=modules/community/community.tcl).

## Required Packages

Community relies on the following external packages:

* sha1 from [tcllib](http://core.tcl.tk/tcllib)
* sqlite3 from [sqlite](http://www.sqlite.org)

Community uses the following internal packages:

* tao from [tao](../tao/tao.md)
* tao-sqlite [tao-sqlite](../tao-sqlite/tao-sqlite.md)

## Options

* dbfile - Path to a file which stores the sqlite database for the community (default in-memory)
* virtual - Root Url of this object.

## Attached Objects

Community objects (and their derived classes) contain an embedded sqlite
database. This database can be accessed via that \<db\> method.

## Methods