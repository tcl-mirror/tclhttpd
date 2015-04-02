Onions have layers. Like ogres. Or parfaits.

# Class tao::layer

## Options

* prefix - A letter code for this layer
* layer\_name - A plaintext name for this layer.
* layer\_index\_order - Integer which expresses what order this layer should be index. (0 first -> infinity)

## Methods

### method node\_is\_managed *unit*

Returns true if an object or record described by *unit* is managed by this object.

### method type\_is\_managed *unit*

Returns true if an type, class or family of records described by *unit* is managed by this object.

# Class tao::onion

## Variables

* layers - A dict containing a mapping of layer names and the objects which implement them.

## Properties

* shared_organs - A list of stubs which are also connected to any node or layer spawned by this object.

## Methods

### method action activate_layers

Action to perform after all of the layer objects have been connected.

### method activate_layers ?1|0?

Using the output of *active_layers*, build a nest of layers. If a *1* is
given as the first argument, all existing layers are unmapped and destroyed
before mapping new layers. Otherwise layers that were previously mapped
and not present in the current incarnation of the object are destroyed. Layers
which exist in the current incarnation, but which arent't mapped are created.
Layers that are mapped, and present in the *active_layers*, but which
have a different class implementation morph into the new class.

### method active_layers

Return a dict describing the layers that should be mapped to this object.

Example:

    method active_layers {} {
      set result {
        xtype     {prefix y class sde.layer.xtype}
        eqpt      {prefix e class sde.layer.eqpt}
        portal    {prefix p class sde.layer.portal}
      }
      return $result
    }
    
### method layer *layerid* ?*method*? ?*args...*?

With only the *layerid* argument, return the object which implements
the layer described by *layerid*. If the layer does not exist, ::noop (a command which takes any argument
and does nothing) is returned.

If more arguments are specified, the command will exercise the *method* of the
layer object using any additional *args*.

Example:

    set obj [::db layer users]
    set username [$obj record_exists $userid]
    
    OR
    
    set exists [::db layer users record_exists $userid]

### method layers

Return a dict describing the layers currently mapped to this object.

### method Shared_Organs

Return a list of organs for this object which should also be grafted to
any layers or other nodes spawned by it. The default implementation is to
return the contents of the value of *property shared_organs*

### Method SubObject layer *name*

Return the fully qualified name of the object which will implement this layer.

The default implementation return \[namespace current\]::SubObject\_Layer\_\$name