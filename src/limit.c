/*
 * setrlimit.c
 * The limit Tcl command.
 */

#include <tcl.h>
#include <sys/time.h>
#include <sys/resource.h>

/*
 * LimitCmd --
 *	Set resource limits.
 *
 * Results:
 *	none
 *
 * Side Effects:
 *	Set resource limits.
 */
int
LimitCmd(ClientData data, Tcl_Interp *interp, int argc, char *argv[])
{
    int max;
    char buf[32];
    struct rlimit limit;
    Tcl_ResetResult(interp);
    if (getrlimit(RLIMIT_NOFILE, &limit) < 0) {
	Tcl_AppendResult(interp, "NOFILE: ", Tcl_PosixError(interp), NULL);
	return TCL_ERROR;
    }
    if (argc > 1) {
	Tcl_GetInt(interp, argv[1], (int *)&limit.rlim_cur);
        if (setrlimit(RLIMIT_NOFILE, &limit) < 0) {
	    Tcl_AppendResult(interp, "NOFILE: ", Tcl_PosixError(interp), NULL);
	    return TCL_ERROR;
	}
    }
    sprintf(interp->result, "%d %d", limit.rlim_cur, limit.rlim_max);
    return TCL_OK;
}

/*
 * Limit_Init --
 *	Initialize the Tcl limit facility.
 *
 * Results:
 *	TCL_OK.
 *
 * Side Effects:
 *	None.
 */
int
Limit_Init(Tcl_Interp *interp)
{
    Tcl_CreateCommand(interp, "limit", LimitCmd, NULL, NULL);
    Tcl_PkgProvide(interp, "limit", "1.0");
    return TCL_OK;
}
