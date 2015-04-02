Back to [tao](../tao.md)

tao-sqlite is a module of related classes which act as ambassadors to **sqlte** database connections.

# Sub-Modules

[yggdrasil](yggdrasil.md)

# Core Classes

## class taodb::connection

Implements a generic wrapper around a database connection. (Note: at this
point only sqlite has been developed.)

Ancestors: [tao.onion](../tao/onions.md)

### Methods

#### method active_layers

Return a list of database layers to act as ambassodors for various
collections of tables. See [onions](../tao/onions.md)

#### method Database_Create

Commands to invoke when the interface attempts to connect to a virgin
database. This method should build the database schema and populate any
starter data.

#### method Database_Functions

Inject functions into the database interface. For sqlite, this method
invokes the interface's native *function* method to map an sqlite function
to a Tcl command.

#### Ensemble schema

Ensemble to manage database schemas.

##### method schema create_sql

Return fully formed SQL code to implement the schema

The default implementation
is to interrogate the object layers for a *schema create_sql* property.

##### method schema tables

Return a list of tables specified by the schema. The default implementation
is to interrogate the object layers for a *schema table* property.


