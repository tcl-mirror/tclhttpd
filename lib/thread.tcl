# threadmgr.tcl
#	Wrappers around basic thread commands

#	"Thread" is the core Tcl package
#	"threadmgr" is the TclHttpd thread manager

package provide threadmgr 1.0

# The "Thread" package is implemented by a C extension.
# We let the main .rc script do the appropriate package
# require, and then fall back to the testthread command if necessary.

if {[catch {package require Thread}]} {
    if {[info commands testthread] == "testthread"} {
	proc thread args {eval testthread $args}
    } else {
	puts stderr "No thread support"
    }
}

# Default is no threading until Thread_Init is called

if {![info exist Thread(enable)]} {
    set Thread(enable) 0
}

# Thread_Init
#
#	Initialize the thread dispatcher
#
# Arguments
#	max	Maximum number of threads to create.
#
# Side Effects
#	Initializes variables used by the thread dispatcher

proc Thread_Init {{max 4}} {
    global Thread
    set Thread(maxthreads) $max	;# Number of threads we can create
    set Thread(threadlist) {}	;# List of threads we have created
    set Thread(freelist) {}	;# List of available threads
    set Thread(queue) {}	;# List of sockets for queued requests
    set Thread(enable) 1
}

# Thread_Disable
#
#	Disable the thread dispatcher
#
# Arguments
#	none
#
# Results
#	none

proc Thread_Disable {} {
    global Thread
    set Thread(enable) 0
}

# Thread_List
#
#	Return the list of threads
#
# Arguments
#	none
#
# Results
#	a list

proc Thread_List {} {
    return [thread names]
}


# Thread_Start --
#	This starts a worker thread.  The big pain here is that a 
#	virgin thread has none of our Tcl scripts, so we have to 
#	bootstrap into a useful state.
#
# Arguments:
#	None
#
# Results:
#	The ID of the created thread

proc Thread_Start {} {
    global auto_path
    set id [Thread_Create] 
    Thread_Send $id \
	{puts stderr "Thread [thread id] starting."}

    # Set up auto_loading

    Thread_Send $id \
	{source $tcl_library/init.tcl}
    Thread_Send $id \
	[list set auto_path $auto_path]

    # Suck up all the necessary packages
    # Most state comes from the initialization in the config file.
    # There is just a bit of info in the Httpd array that is set up
    # when the main server is started, which we need (e.g., the name)

    global Httpd Config
    Thread_Send $id \
	[list array set Httpd [array get Httpd]]
    Thread_Send $id \
	[list array set Config [array get Config]]
    Thread_Send $id \
	[list source $Config(file)]
    Thread_Send $id \
	{puts stderr "Init done for thread [thread id]"}
    
    return $id
}

# Thread_Dispatch --
#	This dispatches the command to a worker thread.
#	That thread should use Thread_Respond or raise an error
#	to complete the request.
#
# Arguments:
#	sock	Client connection
#	cmd	Command to invoke in a worker
#
# Side Effects:
#	Allocate a thread or queue the command/sock for later execution

proc Thread_Dispatch {sock cmd} {
    global Thread
    upvar #0 Httpd$sock data
    if {$Thread(maxthreads) == 0 || !$Thread(enable)} {
	eval $cmd
    } else {
	if {[llength $Thread(freelist)] == 0} {
	    if {[llength $Thread(threadlist)] < $Thread(maxthreads)} {

		# Add a thread to the free pool

		set id [Thread_Start]
		lappend Thread(threadlist) $id
		lappend Thread(freelist) $id
	    } else {
		
		# Queue the request until a thread is available

		lappend Thread(queue) [list $sock $cmd]
		Count threadqueue
puts stderr "Queued request $sock"
		return
	    }
	}
	set id [lindex $Thread(freelist) 0]
	set Thread(freelist) [lrange $Thread(freelist) 1 end]
	set data(master_thread) [thread id]
#puts stderr "Dispatch $sock to thread $id"
	Thread_SendAsync $id [list Thread_Invoke $sock [array get data] $cmd]
    }
}


# Thread_Invoke --
#	This is invoked in a worker thread to handle a request
#
# Arguments:
#	sock	The name of the socket connection.  Probably is not
#		an actual I/O socket.
#	datalist The contents of the connection state in array get format
#	cmd	Tcl command to eval in this thread
#
# Results:
#	None

proc Thread_Invoke {sock datalist cmd} {
    upvar #0 Httpd$sock data
    if {[info exist data]} {
	unset data
    }
    Count urlhits
    array set data $datalist
    if {[catch $cmd result]} {
	global errorInfo errorCode
	Count errors
	Thread_Respond $sock [list Url_Unwind $sock $errorInfo $errorCode]
    } else {
	return $result
    }
}

# Thread_Respond --
#	This is invoked in a worker thread to respond to a request
#
# Arguments:
#	sock	Client connection
#	cmd	Command to invoke to complete the request
#
# Results:
#	1 if the request was passed to the master thread, else 0

proc Thread_Respond {sock cmd} {
    upvar #0 Httpd$sock data
    if {[info exist data(master_thread)] && 
	    $data(master_thread) != [thread id]} {

	# Pass request back to the master thread
	# This includes a copy of the Httpd state (e.g., cookies)

	Thread_SendAsync $data(master_thread) [list Thread_Unwind \
		[thread id] $sock [array get data] $cmd]
	return 1
    } else {
	return 0
    }

}

# Thread_Unwind --
#	Invoke a response handler for a thread
#	This cleans up the connection in the main thread.
#
# Arguments:
#	id	The ID of the worker thread.
#	sock	The ID of the socket connection
#	datalist name, value list for the Httpd state array
#	cmd	The command to eval in the main thread
#
# Side Effects:
#	Invoke the response handler.

proc Thread_Unwind {id sock datalist cmd} {
    upvar #0 Httpd$sock data
    array set data $datalist
    if {[catch $cmd err]} {
	Url_Error $sock
    }
    Thread_Free $id
}

# Thread_Free --
#	Mark a thread as available
#
# Arguments:
#	id	The ID of the worker thread.
#
# Side Effects:
#	Put the thread on the freelist, or perhaps handle
#	a queued request.

proc Thread_Free {id} {
    global Thread
    if {[llength $Thread(queue)] > 0} {
	set state [lindex $Thread(queue) 0]
	set Thread(queue) [lrange $Thread(queue) 1 end]
#puts stderr "Thread_Free $id dispatching to $state"
	set data(master_thread) [thread id]
	set sock [lindex $state 0]
	set cmd [lindex $state 1]
	upvar #0 Thread$sock data
	Thread_SendAsync $id [list Thread_Invoke $sock [array get data] $cmd]
    } else {
	lappend Thread(freelist) $id
    }
}

# Thread_Create --
#	thread create
#
# Arguments:
#	Optional startup script
#
# Results:
#	The ID of the created thread

proc Thread_Create {{script {}}} {
    Count threads
    if {[string length $script]} {
	return [thread create $script]
    } else {
	return [thread create]
    }
}

# Thread_Send --
#	thread send
#
# Arguments:
#	id	Target thread
#	script	Script to send
#
# Results:
#	The results of the script

proc Thread_Send {id script} {
    if {[catch {thread send $id $script} result]} {
puts stderr "Send Failed $result"
	return -code error $result
    } else {
	return $result
    }
}

# Thread_SendAsync --
#	thread send -async
#
# Arguments:
#	id	Target thread
#	script	Script to send
#
# Results:
#	The results of the script

proc Thread_SendAsync {id script} {
    if {[catch {thread send -async $id $script} result]} {
puts stderr "Send Failed $result"
	return -code error $result
    } else {
	return $result
    }
}

# Thread_Id --
#	thread id
#
# Arguments:
#	none
#
# Results:
#	The thread ID

proc Thread_Id {} {
    thread id
}

# Thread_IsFree --
#	Find out if a thread is on the free list.
#
# Arguments:
#	id	The thread ID
#
# Results:
#	1 or 0

proc Thread_IsFree {id} {
    global Thread
    return [expr {[lsearch $Thread(freelist) $id] <= 0}]
}

