# objects.tcl
#
# Provides a hook for objects to process URLs
# Object that are connected are expected to expose the method:
#
# httpdMarshallArguments [suffix] [cgiList]
#
# Returns a command that is immediately evaluated, usually in the
# form of [object] [method] [key/value list]
#
# For an example of this system in action, see custom/objects.tcl
# in the distribution
#
# Copyright
# Sean Woods (c) 2008
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: objects.tcl,v 1.1 2008/05/06 00:17:47 eviltwinskippy Exp $


package provide httpd::objects 1.0


# Object_Url
#	Define a subtree of the URL hierarchy that is implemented by
#	direct Tcl calls to a Tao Object.
#
# Arguments
#	virtual The name of the subtree of the hierarchy, e.g., /device
#	object	The Tcl object to use when constructing calls,
#		e.g. Device
#	inThread	True if this should be dispatched to a thread.
#
# Side Effects
#	Register an object

proc ::Object_Url {virtual object {inThread 0}} {
    global Direct
    set Direct($object) $virtual    ;# So we can reconstruct URLs
    Url_PrefixInstall $virtual [list ObjectDomain $object] $inThread
}

# Object_UrlRemove
#       Remove a subtree of the URL hierarchy that is implemented by
#       direct Tcl calls.
#
# Arguments
#       object  The Tcl object used when constructing calls,
#
# Side Effects
#
       
proc ::Object_UrlRemove {object} {
    global Direct
    catch { Url_PrefixRemove $Direct($object) }
    catch { unset Direct($object) }
}
        
# Main handler for Object domains (i.e. tcl commands)
# object: the object registered with Object_Url 
# sock: the socket back to the client
# suffix: the part of the url after the object.
#
# This calls out to the Object with the suffix being either
# a direct method to this object, a reference to an object
# and a method to call to the referered object.
#
# All parameters from the form are fed into a Dict
# All object method called must be prefixed with "httpd"
#
# Example:
# Object_Url /device Device
# if the URL is /device/a/display, then the Tcl command to handle it
# should be
# proc [Device /node a] httpdDisplay
#
# You can define the content type for the results of your procedure by
# modifying the global ::page(content-type) field
#
# ::page(content-type) is reset to text/html every pageview

proc ::ObjectDomain {object sock suffix} {
    global Direct
    global env
    upvar #0 Httpd$sock data
    global page
    set page(content-type) text/html

    # Set up the environment a-la CGI.

    Cgi_SetEnv $sock $object
    #$suffix

    # Prepare an argument data from the query data.

    Url_QuerySetup $sock
    set cmd [$object httpdMarshallArguments $suffix [::ncgi::nvlist]]
    
    if {$cmd == ""} {
	Doc_NotFound $sock
	return
    }
    set code [catch $cmd result]
    
    ::Object_Respond $sock $code $result $page(content-type)
}

# Object_Respond --
#
#	This function returns the result of evaluating the object
#	url.  Usually, this involves returning a page, but a redirect
#	could also occur.
#
# Arguments:
# 	sock	The socket back to the client.
#	code	The return code from evaluating the direct url.
#	result	The return string from evaluating the direct url.
#	type	The mime type to use for the result.  (Defaults to text/html).
#
# Notes: Cargo Culted from Direct_Url Code. May start to differ later.
#
# Results:
#	None.
#
# Side effects:
#	If code 302 (redirect) is passed, calls Httpd_Redirect to 
#	redirect the current request to the url in result.
#	If code 0 is passed, the result is returned to the client.
#	If any other code is passed, an exception is raised, which
#	will cause a stack trace to be returned to the client.
#

proc ::Object_Respond {sock code result {type text/html}} {
    switch $code {
	0 {
	    # Fall through to Httpd_ReturnData.
	}
	302	{
	    # Redirect.

	    Httpd_Redirect $result $sock
	    return ""
	}
	default {
	    # Exception will cause error page to be returned.

	    global errorInfo errorCode
	    return -code $code -errorinfo $errorInfo -errorcode $errorCode \
		    $result
	}
    }

    # See if a content type has been registered for the URL.

    # Save any return cookies which have been set.
    # This works with the Doc_SetCookie procedure that populates
    # the global cookie array.
    ::Cookie_Save $sock

    ::Httpd_ReturnData $sock $type $result
    return ""
}
