diff --git a/usr/src/sys/cddl/contrib/opensolaris/uts/common/dtrace/dtrace.c.orig b/usr/src/sys/cddl/contrib/opensolaris/uts/common/dtrace/dtrace.c
index 3fbd432..075092a 100644
--- a/usr/src/sys/cddl/contrib/opensolaris/uts/common/dtrace/dtrace.c.orig
+++ b/usr/src/sys/cddl/contrib/opensolaris/uts/common/dtrace/dtrace.c
@@ -165,6 +165,7 @@ int		dtrace_destructive_disallow = 0;
 int		dtrace_allow_destructive = 1;
 #endif
 dtrace_optval_t	dtrace_nonroot_maxsize = (16 * 1024 * 1024);
+dtrace_optval_t	dtrace_buffer_maxsize = (16 * 1024 * 1024);
 size_t		dtrace_difo_maxsize = (256 * 1024);
 dtrace_optval_t	dtrace_dof_maxsize = (8 * 1024 * 1024);
 size_t		dtrace_statvar_maxsize = (16 * 1024);
@@ -12031,17 +12032,10 @@ err:
 #else
 	int i;
 
-	*factor = 1;
-#if defined(__aarch64__) || defined(__amd64__) || defined(__arm__) || \
-    defined(__mips__) || defined(__powerpc__) || defined(__riscv__)
-	/*
-	 * FreeBSD isn't good at limiting the amount of memory we
-	 * ask to malloc, so let's place a limit here before trying
-	 * to do something that might well end in tears at bedtime.
-	 */
-	if (size > physmem * PAGE_SIZE / (128 * (mp_maxid + 1)))
+	if (size > dtrace_buffer_maxsize)
 		return (ENOMEM);
-#endif
+
+	*factor = 1;
 
 	ASSERT(MUTEX_HELD(&dtrace_lock));
 	CPU_FOREACH(i) {
