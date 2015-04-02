The Tao package is a framework built on top of TclOO. Classes and objects
created in Tao are 100% compadible with standard TclOO.

Tao adds a host of features that is not available in vanilla TclOO
They include the following:

* [events](events.md)
* [options](options.md)
* [moac](moac.md)
* [parser](parser.md)
* [signals](signals.md)
* [taodb](taodb.md)

# Development

Tao is maintained at <http://fossil.etoyoc.com/fossil/taolib>.
If you are viewing this file from within tclhttpd's sources, you are
viewing a snapshot that is periodically updated from the mainstream
sources.

Tao was built, designed, and maintained by Sean Woods <yoda@etoyoc.com>.

# Major Concepts

* All tao framework objects decend from the [Mother of all Classes](moac.md)
* Tao classes are built using the *::tao::class* keyword, instead of *::oo::class create*
* Tao classes can be modified using the *::tao::class* keyword, instead of *::oo::define*
* A method in \<brackets\> indicates that the method is actually being forwarded to another object.
* *::tao::class* is a pre-parser, which adds additional keywords and modifies the behavior of the constructor and destructor
