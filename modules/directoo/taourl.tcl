package require tao
package require httpd::directoo


tao::class httpd.taourl {
  superclass httpd.meta

  property options_strict 0

  constructor {virtual {localopts {}} args} {
    my configurelist [list virtual $virtual {*}$localopts]
    ::Url_PrefixInstall $virtual [namespace code {my httpdDirect}] {*}$args
    my initialize
  }
}

package provide httpd::taourl 0.1
