
# Compat routines with 3.4 routines

catch {interp alias {} Doc_Dynamic {} Template_Dynamic}
catch {interp alias {} Doc_Redirect {} Redirect_To}
catch {interp alias {} Doc_RedirectSelf {} Redirect_Self}

catch {interp alias {} Doc_Webmaster {} Httpd_Webmaster}
catch {interp alias {} Httpd_RedirectDir {} Redirect_Dir}