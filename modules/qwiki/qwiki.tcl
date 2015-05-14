###
# Implements a barebone wiki in a community object
###

package require httpd::community

tao::class qwiki.layer.wiki {
  superclass community.layer

  property module user
  property schema version 1.0  
  property schema table qwiki
  property schema primary_key entryid
  
  property schema create_sql {
    create table if not exists qwiki (
      qwikid uuid default (uuid_generate()),
      indexed integer default 0,
      parent uuid references qwiki (qwikid) ON UPDATE CASCADE ON DELETE SET NULL,
      acl_name  string references acl (acl_name) ON UPDATE CASCADE ON DELETE SET NULL,
      class string,
      format string,
      title string,
      body text,
      ctime unixtime default now(),
      mtime unixtime default now(),
      primary key (qwikid)
    );

    create table if not exists qwiki_property (
      qwikid    string references qwiki (qwikid) ON UPDATE CASCADE ON DELETE CASCADE,
      field      string,
      value      string,
      primary key (qwikid,field)
    );

    create table if not exists qwiki_link (
      linktype string,
      qwiki integer references qwiki (qwikid) ON UPDATE CASCADE ON DELETE CASCADE,
      refqwiki integer references qwiki (qwikid)  ON UPDATE CASCADE ON DELETE CASCADE
    );
    
    -- Generate initial content
    insert into qwiki(qwikid,title,class,format,page) VALUES (local.homepage,'Home','page','markdown','Welcome to Qwiki!');
    -- Generate a FTS
    CREATE VIRTUAL TABLE qwiki_search USING fts4(title, body);
  }

  
}

tao::class httpd.qwiki {
  superclass httpd.community

  constructor {virtual {localopts {}} args} {
    my configurelist [list virtual $virtual threadargs $args {*}$localopts]
    ::Url_PrefixInstall $virtual [namespace code {my httpdDirect}] {*}$args
    my initialize
  }

  method active_layers {} {
    return {
      user    {prefix uid class community.layer.user}
      group   {prefix gid class community.layer.group}
      session {prefix sesid class community.layer.session}
      acl     {prefix acl class community.layer.acl}
      wiki    {prefix wiki class qwiki.layer.wiki}
    }
  }
  
  method /html args {
    my layer wiki /html local.homepage
  }


}

package provide httpd::qwiki 0.1