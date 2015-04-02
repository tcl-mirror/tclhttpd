# Class tao::moac

All classes in the Tao framework decend from tao::moac.

# Concepts

Back to [tao](tao.md)

* [taodb](taodb.md)
* [events](events.md)
* [options](options.md)
* [parser](parser.md)
* [signals](signals.md)

# Options

* trace - When true, enable tracing information to stdout

# Properties

* options_strict - Default 0. When true, attempts to access an option through configure
or cget, which was not declared by the *option* keyword, or inherited from another class, will fail.

# Variables

* ActiveLocks - A list of active locks
* organs - A dict containing the mapping of stubs to objects

# Methods

## action::busy

Indicate to the user that the program is processing. (Empty method)

## action::idle

Commands to run when the system releases the gui. (Empty method)

## action::morph_enter

Commands to perform as an object enters this new class via the *morph* method. (Empty method)

## action::morph_leave

Commands to perform as an object exits the current class via the *morph* method. (Empty method)

## action::pipeline_busy

Commands to run when the system releases the locks. (Empty method)

** method cget *field* *?default?*

Return the value for an option, or of the option is null return *default*.
Dashes are stripped from the left of all fields.

** method code

Return \[namespace code {self}\]

## method configure *keyvaluelist*|*key* *value* ?*key* *value*...

Modify options. The command accepts either a single argument (a key value list), or
a series of keys. Dashes are stripped from the left of all fields.

Internally, *configure* normalizes the inputs, and passes them to *configurelist* and
*configurelist_triggers*.

## method configurelist *keyvaluelist*

Perform validation checks and modify the internal configuration of the
object. This method will not trigger modification events.

## method event cancel ?*pattern*?

Cancel a scheduled event. If *pattern* not specified, all scheduled tasks are
cancelled. If *pattern* given, all task handles that match *pattern* are cancelled.
Patterns are those used by *array get*.

(Note: this method is actually a forward to ::tao::event::cancel)

## method event generate *event* *args...*

Generate an event of type *event* which will be passed to the *notify* method
of all objects subscribed to *event*.

(Note: this method is actually a forward to ::tao::event::generate)

## method event nextid

Return a unique name for an event.

## method event Notification_list *pattern*

Called recursively to produce a list of who recieves notifications of pattern *pattern*.

(Note: this method is actually a forward to ::tao::event::Notification\_list)

## method event publish *object_pattern* *event_pattern*

Create a subscription for objects specified by *object_pattern* to events specified by *event_pattern*.
Patterns should be any pattern suitiable for \[string match\]

## method event schedule *handle* *interval* *script*

Arrange for *script* to be called after *interval*. Interval is any value acceptable to
\[after\]. A successive call to *handle* will cancel the prior event and schedule a new one.

## method event subscribe *object_pattern* *event_pattern*

Create a subscription for the current object to events emitted by objects
specified by *object_pattern* to events specified by *event_pattern*.
Patterns should be any pattern suitiable for \[string match\]

## method event unpublish *?event_pattern?*

Remove any subscriptions to this object's events that match *event_pattern*. If *event_pattern*
not given, all subscriptions are removed.

## method event unsubscribe *?event_pattern?*

Remove any subscriptions this object has made to events that match *event_pattern*. If *event_pattern*
not given, all subscriptions are removed.

## method forward *method* *?args...?*

Forward *method* to the command specified by *args*. Internally this is just a
wrapper around \[oo::objdefine forward\]

## method graft *stub* *object* ?*stub* *object*...?

Calles to \<*stub*\> for this object will now forward to the *object* (or ensemble)
specified. A mapping of stub->object is stored internally as a dict in the *organs* variable.

## method initialize

Called during the constructor to
set up all local variables and data
structures. It is a seperate method
to ensure inheritence chains predictably
and also to keep us from having to pass
along the constructor's arguments.

## method InitializePublic

Provide a default value for all options and
publically declared variables, and locks the
pipeline mutex to prevent signal processing
while the contructor is still running. A call to
this method is automatically injected into the constructor
by the Tao preprocessor's *constructor* keyword.

Note, by default a Tao object will ignore
signals until a later call to *my lock remove pipeline*

## method lock active

Return a list of active locks.

## method lock create *lock* ?*lock*...?

Add all arguments as locks if they are not already in the list of locks.

## method lock peek *lock* ?*lock*...?

Returns true if any of the locks specified is active.

## method lock remove *lock* ?*lock*...?

Remove the locks specified. If the last lock has been removed, a call to
*lock remove_all* is made.

## method lock remove_all

Removes all locks and makes a call to *Signal_pipeline*

## method message error *error* *errorInfo*

Process a background error

## method morph *newclass*

Have this object transition to *newclass* (if it isn't already that class).

The following snippet describes the steps:

      # CALLED AS THE PRESENT CLASS
      my action morph_leave
      oo::objdefine [self] class ::${newclass}
      # CALLED AS THE NEW CLASS
      my variable config
      set savestate $config
      my InitializePublic
      my configurelist $savestate
      my action morph_enter
    
The InitializePublic call ensures that any internal variables and options
that are declared in the new class, but not present in the current class,
are initialized.

## method mutex down *flag*

Remove mutex *flag*. Return 1 if the mutex was active, 0 otherwise.

## method mutex peek *flag*

Return 1 if mutex *flag* is active, 0 otherwise.

## method mutex up *flag*

Attempt to establish a mutex *flag*. If mutex is already active, return 1.
If a new mutex was successfully established, return 0.

## Ensemble notify *eventtype* *info*

Process an incoming notification of *eventtime* immediately.

## Ensemble Option_set *field* *newvalue*

Called by *configurelist_triggers*

Process and incoming change to an option.

## method OptionsMirrored *stub*

Return a list of options which should be mirrored to an object attached as \<*stub*\>.

## method organ *?stub?*

Return the path to the object attached as \<*stub*\>. If stub not given, return a key/value
list of all stubs and objects.

## method Prefs_Load

Load persistant preferences for this object. (Empty method)

## method Prefs_Store dictargs

Store persistant preferences for this object. (Empty method)

## method private *method* ?*args...*?

Invoke a normally private method publically.

## method signal ?*signal* *signal...*?

Generate a signal, which will ultimately schedule a call to *Signal_pipeline*. The call
of one signal can trigger or suppress other signals. See [signals](signals.md)
