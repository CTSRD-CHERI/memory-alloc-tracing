diff --git a/usr/src/sys/cddl/dev/dtrace/dtrace_sysctl.c.orig b/usr/src/sys/cddl/dev/dtrace/dtrace_sysctl.c
index eea9802..34b03cb 100644
--- a/usr/src/sys/cddl/dev/dtrace/dtrace_sysctl.c.orig
+++ b/usr/src/sys/cddl/dev/dtrace/dtrace_sysctl.c
@@ -93,5 +93,11 @@ SYSCTL_QUAD(_kern_dtrace, OID_AUTO, dof_maxsize, CTLFLAG_RW,
 SYSCTL_QUAD(_kern_dtrace, OID_AUTO, helper_actions_max, CTLFLAG_RW,
     &dtrace_helper_actions_max, 0, "maximum number of allowed helper actions");
 
+SYSCTL_QUAD(_kern_dtrace, OID_AUTO, buffer_maxsize, CTLFLAG_RW,
+    &dtrace_buffer_maxsize, 0, "maximum capture buffer size");
+
+SYSCTL_QUAD(_kern_dtrace, OID_AUTO, strsize_default, CTLFLAG_RW,
+    &dtrace_strsize_default, 0, "maximum string szie");
+
 SYSCTL_INT(_security_bsd, OID_AUTO, allow_destructive_dtrace, CTLFLAG_RDTUN,
     &dtrace_allow_destructive, 1, "Allow destructive mode DTrace scripts");
