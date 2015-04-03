*httpd.community* is a decendent of . It adds an sqlite based user, group, and access control system. It is implemented in [community.tcl](finfo?name=modules/community/community.tcl).

## Ancestors

* [httpd.taourl](../directoo/taourl.md)
* [yggdrasil](../tao-sqlite/yggdrasil.md)

## Required Packages

Community relies on the following external packages:

* sha1 from [tcllib](http://core.tcl.tk/tcllib)
* sqlite3 from [sqlite](http://www.sqlite.org)

Community uses the following internal packages:

* tao from [tao](../tao/tao.md)
* tao-sqlite [tao-sqlite](../tao-sqlite/tao-sqlite.md)

## Properties

* create\_sql - An SQL script that implements the schema

## Options

* dbfile - Path to a file which stores the sqlite database for the community (default in-memory)
* virtual - Root Url of this object.

## Attached Objects

Community objects (and their derived classes) contain an embedded sqlite
database. This database can be accessed via that \<db\> method.

## Methods

### method Database\_Functions

Adds the following functions to the database:

* uuid\_generate() - Generates sha1 UUIDs on demand
* sha1() - Returns the SHA1 hash of the input

### aclAccessTypes

Returns a list of all possible rights.

### aclRights *aclname* *user\_or\_group\_id*

Return a list of rights that the user or group to the access control list (specified by name.)

### method httpdSessionLoad *sock* *prefix* *suffix*

This method looks for a sessionid cookie or a sessionid field in the GET or POST query, and
pairs it with a session in the *session* table. If no session is found, a new session is generated
for an anonymous user.

### method httpdSessionSave *sock*

This method compares the current value of **result\(session\)** to **result\(session\_delta\)** (a copy
of the session when the pageview began. Fields that are in the delta, but not in the current session are delete
from **session\_property**. Fields that are present in the session but not the delta are inserted into
**session\_property**. Fields present in both, but with a different value, are updated.

The server will generate a cookie called **sessionid** which will be loaded on the next page view.