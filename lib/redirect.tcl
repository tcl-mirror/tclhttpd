# redirect.tcl
#
#	Domain that redirects everything elsewhere
#

package provide redirect 1.0

# RedirectDomain
#	Set up a domain that redirects requests elsewhere
#	To use, make a call like this:
#
#	Url_PrefixInstall /olddir [list RedirectDomain /newdir]
#
# Arguments:
#	prefix	The Prefix of the domain
#	url	The other URL to which to redirect
#
# Results:
#	This always raises a redirect error

proc RedirectDomain {url sock suffix} {
    set newurl $url$suffix
    Httpd_Redirect $newurl $sock
}

# Redirect_UrlTree
#	Map a whole URL hierarchy to a new place
#
# Arguments:
#	old	Old location, (e.g., /olddir)
#	new	New location, (e.g., /newdir)
#
# Side Effects:
#	Future requests to old/a/b/c will redirect to new/a/b/c

proc Redirect_UrlTree {old new} {
    Url_PrefixInstall $old [list RedirectDomain $new]
}
