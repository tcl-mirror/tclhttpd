# The httpd.url class

[Implementation](finfo?name=modules/httpd/directoo.tcl)

*httpd.url* is a TclOO class. The first argument (after the name of the new object) is the virtual root for this object. For more complex classes, the second argument is a key/value list of configuration options. Any arguments after that are passed to *Url_PrefixInstall*

## Variables

### env

An array which contains CGI data. It is populated every page view *Cgi_SetEnv* in Tclhttpd.

### result

An array which contains the meta information and content about the page view in progress. Important fields:

* code - HTTP code to return (default 400)
* body - The block of data to be sent via *Httpd_ReturnData* or *Httpd_ReturnCacheableData* at the conclusion of the operation.
* content-type - The type of content in *block* (default text/html)

## Methods

### configurelist *keyvaluelist*

Pass configuration items as a key/value list.

### cget *field*

Retrieve the value of a configuration item

### /html

A method which implements the default root page of the object.

### initialize

A method which is called in the constructor, after the configuration items have been applied and the domain registered with Tclhttpd.

### httpdDirect *sock* *suffix*

This method is the first called when resolving a dynamic page. It calles *httpdSessionLoad* to load the session, *httpdMarshalArguments* do compute the method to call. On error, this method returns an error message. On success it calls *httpdSessionSave*, before sending the resulting data out to TclHttpd via the *Httpd_ReturnData* or *Httpd_ReturnCacheableData* procs.

### httpdMarshalArguments *sock* *suffix*

Calculate the command which will implement the current page view.

### httpdSessionLoad *sock *prefix* *suffix*

Initializes the *result* variable, and load session data from either cookies or the incoming GET/POST query. This method also calls the *Cgi_SetEnv* and *Url_QuerySetup* procs from Tclhttpd. Rather than populate the global *env* variable, Cgi_SetEnv populates the private *env* variable for this object.

### httpdSessionSave *sock*

Updates the current session, and writes cookies back to the browser.

### reset

Reset the current value of result(body)

### puts

Append to the value of result(body). Accepts multiple arguments. An implied \n is appended at the tail end.

### unknown *args*

Handler for unknown, incomplete, or invalid queries.