# Tcl package index file, version 1.0
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded admin 1.0 [list tclPkgSetup $dir admin 1.0 {{admin.tcl source {Admin/redirect Admin/redirect/reload Admin_Url}}}]
package ifneeded auth 1.0 [list tclPkgSetup $dir auth 1.0 {{auth.tcl source {AuthGetPass AuthGroupCheck AuthNetMatch AuthNullCallback AuthParseHtaccess AuthVerifyBasic AuthVerifyNet AuthVerifyTcl Auth_AccessFile Auth_Check Auth_Verify Ht-/limit Ht-allow Ht-authgroupfile Ht-authname Ht-authtype Ht-authuserfile Ht-deny Ht-limit Ht-order Ht-require HtByNet}}}]
package ifneeded base64 1.0 [list tclPkgSetup $dir base64 1.0 {{base64.tcl source {Base64_Decode Base64_Encode}}}]
package ifneeded cgi 1.1 [list tclPkgSetup $dir cgi 1.1 {{cgi.tcl source {CgiCancel CgiCleanup CgiClose CgiHandle CgiRead CgiSpawn Cgi_Directory Cgi_Domain Cgi_Ident Cgi_SetEnv Cgi_SetEnvAll Doc_application/x-cgi}}}]
package ifneeded counter 1.0 [list tclPkgSetup $dir counter 1.0 {{counter.tcl source {Count CountHist CounterMergeDay CounterMergeHour Counter_CheckPoint Counter_Get Counter_Init Counter_Reset Counter_StartTime}}}]
package ifneeded debug 1.0 [list tclPkgSetup $dir debug 1.0 {{debug.tcl source {Debug/after Debug/dbg Debug/echo Debug/errorInfo Debug/goof Debug/package Debug/parray Debug/pvalue Debug/raise Debug/source DebugValue Debug_Url}}}]
package ifneeded demo 1.0 [list tclPkgSetup $dir demo 1.0 {{demo.tcl source {Demo/addnode Demo/hello Demo/urlnote}}}]
package ifneeded direct 1.0 [list tclPkgSetup $dir direct 1.0 {{direct.tcl source {DirectDomain Direct_Url}}}]
package ifneeded dirlist 1.0 [list tclPkgSetup $dir dirlist 1.0 {{dirlist.tcl source {DateCompare DirList DirlistCompare}}}]
package ifneeded doc 1.1 [list tclPkgSetup $dir doc 1.1 {{doc.tcl source {DocAccept DocCheckTemplate DocChoose DocDirectory DocDomain DocExclude DocFallback DocHandle DocLatest DocMatch DocSubst DocSubstSystemFile DocTemplate Doc_AddRoot Doc_CheckTemplates Doc_Error Doc_ErrorPage Doc_ExcludePat Doc_File Doc_IndexFile Doc_NotFound Doc_NotFoundPage Doc_PublicHtml Doc_Root Doc_Subst Doc_TemplateInterp Doc_TemplateLibrary Doc_Virtual Doc_Webmaster Doc_application/x-imagemap Doc_application/x-tcl-auth Doc_application/x-tcl-subst Doc_application/x-tcl-template Doc_text/html}}}]
package ifneeded html 1.0 [list tclPkgSetup $dir html 1.0 {{html.tcl source {Html_ExtractParam Html_ValueList}}}]
package ifneeded httpd 1.1 [list tclPkgSetup $dir httpd 1.1 {{httpd.tcl source {HttpdAccept HttpdCancel HttpdClose HttpdCopy HttpdCopyDone HttpdDate HttpdPostData HttpdRead HttpdReset HttpdRespondHeader Httpd_Error Httpd_Init Httpd_Peername Httpd_Redirect Httpd_RedirectDir Httpd_RedirectSelf Httpd_RegisterShutdown Httpd_RequestAuth Httpd_ReturnCacheableData Httpd_ReturnData Httpd_ReturnFile Httpd_SelfUrl Httpd_Server Httpd_Shutdown Httpd_SockClose bgerror}} {version.tcl source Httpd_Version}}]
package ifneeded include 1.0 [list tclPkgSetup $dir include 1.0 {{include.tcl source {Doc_application/x-server-include IncludeFile IncludeInner Include_Html include_config include_echo include_exec include_flastmod include_fsize include_include}}}]
package ifneeded ismaptcl 1.0 [list tclPkgSetup $dir ismaptcl 1.0 {{imagemap.tcl source {MapPointInCircle MapPointInPoly MapPointInRect MapTest}} {maptcl.tcl source {MapHit MapInsert MapRead Map_Lookup}}}]
package ifneeded ismaptk 1.0 [list tclPkgSetup $dir ismaptk 1.0 {{maptk.tcl source {MapHit MapInsert MapRead Map_Lookup}}}]
package ifneeded log 1.0 [list tclPkgSetup $dir log 1.0 {{log.tcl source {Log LogValue Log_Array Log_Configure Log_Flush Log_FlushMinutes Log_SetFile}}}]
package ifneeded mail 1.0 [list tclPkgSetup $dir mail 1.0 {{mail.tcl source {Mail/bugreport Mail/formdata Mail/forminfo MailInner Mail_FormInfo Mail_Url}}}]
package ifneeded mtype 1.0 [list tclPkgSetup $dir mtype 1.0 {{mtype.tcl source {Mtype Mtype_ReadTypes}}}]
package ifneeded opentrace 1.0 [list tclPkgSetup $dir opentrace 1.0 {{open.tcl source {close-orig open-orig}}}]
package ifneeded session 1.0 [list tclPkgSetup $dir session 1.0 {{session.tcl source {Dummy_Init SessionAuthorizedAliases SessionCreate SessionTypeAliases Session_Authorized Session_Create Session_CreateWithID Session_Destroy Session_Import Session_Match Session_Reap Session_Require Session_Sequence Session_Session Session_Value Session_Variable}}}]
package ifneeded snmp 1.0 [list tclPkgSetup $dir snmp 1.0 {{discover.tcl source {DiscoverCallback MyIpaddr MyNet SnmpDiscover}} {snmp.tcl source {Doc_application/x-tcl-snmp SnmpDebug SnmpInit SnmpProcess Snmp_DisplayMib Snmp_SessionPage Snmp_Walk Snmp_combo Snmp_discover Snmp_formGroup Snmp_formSession Snmp_host Snmp_hostId Snmp_input Snmp_mibTable Snmp_netId Snmp_radio Snmp_select Snmp_setMib}} {telnet.tcl source {Import_clear Telnet expect mung mung2}}}]
package ifneeded srvui 1.0 [list tclPkgSetup $dir srvui 1.0 {{srvui.tcl source SrvUI_Init}}]
package ifneeded status 1.1 [list tclPkgSetup $dir status 1.1 {{status.tcl source {Doc_application/x-tcl-status Status Status/ Status/all Status/codesize Status/datasize Status/doc Status/hello Status/notfound Status/notfound/reset Status/size Status/text StatusMainTable StatusMenu StatusMinuteHist StatusPrintArray StatusPrintHits StatusPrintNotFound StatusSort StatusSortForm StatusSortName StatusTclPower StatusTimeText Status_Url Version}}}]
package ifneeded stdin 1.1 [list tclPkgSetup $dir stdin 1.1 {{stdin.tcl source {StdinRead Stdin_Start bgerror history}}}]
package ifneeded survey 1.0 [list tclPkgSetup $dir survey 1.0 {{survey.tcl source {DataChoice FormAction Survey/download Survey/showfiles}}}]
package ifneeded url 1.0 [list tclPkgSetup $dir url 1.0 {{url.tcl source {UrlSort Url_Decode Url_DecodeQuery Url_Dispatch Url_Encode Url_Handle Url_PathCheck Url_PrefixInstall Url_Redirect Url_RedirectSelf Url_UnCache}}}]
package ifneeded utils 1.0 [list tclPkgSetup $dir utils 1.0 {{utils.tcl source {ChopLine File_List File_Reset Incr Scroll_Set Scrolled_Canvas Scrolled_Listbox Scrolled_Text Stderr boolean iscommand lappendOnce lassign lassign-brent ldelete makedir matchOption optionConfigure optionSet parray poptions protect_text randomx setmax setmin}}}]
