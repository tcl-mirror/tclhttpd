# compat.tcl
#@c Compatibility layer - deprecated
#
# Derived from doc.tcl
# Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# Colin McCormack (c) 2002
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: compat.tcl,v 1.1.2.1 2002/08/04 01:25:19 coldstore Exp $

foreach {oldname newname} {
    Doc_NotFound	Error_NotFound
    Doc_NotFoundPage	Error_NotFoundPage
    Doc_ErrorPage	Error_ErrorPage
    Doc_Error		Error_Error
    Doc_GetCookie	Cookie_Get
    Doc_SetCookie	Cookie_Set
    Doc_IsLinkToSelf	Url_IsLinkToSelf
    Doc_Redirect	Redirect_To
    Doc_RedirectSelf	Redirect_Self
    Doc_IsLinkToSelf	Url_IsLinkToSelf
    Doc_IndexFile	DirList_IndexFile
    Doc_Webmaster	Httpd_Webmaster
    Doc_CheckTemplates	Template_Check
    Doc_TemplateInterp	Template_Interp
    Doc_TemplateLibrary	Template_Library
    Doc_Dynamic		Template_Dynamic
    Doc_Subst		Subst_ReturnFile

    Url_Redirect	Redirect_Url
    Url_RedirectSelf	Redirect_UrlSelf

} {
    interp alias {} $oldname {} $newname
}

