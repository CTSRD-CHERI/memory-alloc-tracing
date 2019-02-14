diff --git a/usr/src/sys/kern/kern_sig.c.orig b/usr/src/sys/kern/kern_sig.c
index ec1423f..3cc1a05 100644
--- a/usr/src/sys/kern/kern_sig.c.orig
+++ b/usr/src/sys/kern/kern_sig.c
@@ -176,6 +176,17 @@ static int	do_coredump = 1;
 SYSCTL_INT(_kern, OID_AUTO, coredump, CTLFLAG_RW,
 	&do_coredump, 0, "Enable/Disable coredumps");
 
+/* XXX-LPT */
+static int  coredump_on_sigkill = 0;
+SYSCTL_INT(_kern, OID_AUTO, coredump_on_sigkill, CTLFLAG_RW, &coredump_on_sigkill,
+    0, "Dump a core and continue in the event of SIGKILL");
+static int  coredump_on_sigusr1 = 0;
+SYSCTL_INT(_kern, OID_AUTO, coredump_on_sigusr1, CTLFLAG_RW, &coredump_on_sigusr1,
+    0, "Dump a core and continue in the event of SIGUSR1");
+static int  coredump_on_sigusr2 = 0;
+SYSCTL_INT(_kern, OID_AUTO, coredump_on_sigusr2, CTLFLAG_RW, &coredump_on_sigusr2,
+    0, "Dump a core and continue in the event of SIGUSR2");
+
 static int	set_core_nodump_flag = 0;
 SYSCTL_INT(_kern, OID_AUTO, nodump_coredump, CTLFLAG_RW, &set_core_nodump_flag,
 	0, "Enable setting the NODUMP flag on coredump files");
@@ -206,7 +217,7 @@ static int sigproptbl[NSIG] = {
 	SA_KILL|SA_CORE,		/* SIGABRT */
 	SA_KILL|SA_CORE,		/* SIGEMT */
 	SA_KILL|SA_CORE,		/* SIGFPE */
-	SA_KILL,			/* SIGKILL */
+	SA_KILL,			/* SIGKILL */  /* XXX-LPT May be overriden by coredump_on_sigkill */
 	SA_KILL|SA_CORE,		/* SIGBUS */
 	SA_KILL|SA_CORE,		/* SIGSEGV */
 	SA_KILL|SA_CORE,		/* SIGSYS */
@@ -227,8 +238,8 @@ static int sigproptbl[NSIG] = {
 	SA_KILL,			/* SIGPROF */
 	SA_IGNORE,			/* SIGWINCH  */
 	SA_IGNORE,			/* SIGINFO */
-	SA_KILL,			/* SIGUSR1 */
-	SA_KILL,			/* SIGUSR2 */
+	SA_KILL,			/* SIGUSR1 */  /* XXX-LPT May be overriden by coredump_on_sigusr1 */
+	SA_KILL,			/* SIGUSR2 */  /* XXX-LPT ditto by coredump_on_sigusr2 */
 };
 
 static void reschedule_signals(struct proc *p, sigset_t block, int flags);
@@ -633,8 +644,13 @@ static __inline int
 sigprop(int sig)
 {
 
-	if (sig > 0 && sig < NSIG)
+	if (sig > 0 && sig < NSIG) {
+		if ((sig == SIGKILL && coredump_on_sigkill) ||
+			(sig == SIGUSR1 && coredump_on_sigusr1) ||
+			(sig == SIGUSR2 && coredump_on_sigusr2))
+			return SA_CORE;
 		return (sigproptbl[_SIG_IDX(sig)]);
+	}
 	return (0);
 }
 
@@ -3029,14 +3045,30 @@ postsig(sig)
 	}
 
 	if (action == SIG_DFL) {
-		/*
-		 * Default action, where the default is to kill
-		 * the process.  (Other cases were ignored above.)
-		 */
-		mtx_unlock(&ps->ps_mtx);
-		proc_td_siginfo_capture(td, &ksi.ksi_info);
-		sigexit(td, sig);
-		/* NOTREACHED */
+		if (sigprop(sig) & SA_KILL) {
+			/*
+			 * Default action, where the default is to kill
+			 * the process.
+			 */
+			mtx_unlock(&ps->ps_mtx);
+			proc_td_siginfo_capture(td, &ksi.ksi_info);
+			sigexit(td, sig);
+			/* NOTREACHED */
+		} else if ((sigprop(sig) & SA_CORE)) {
+			/* XXX-LPT
+			 * Default action, where the core is dumped and
+			 * the process continues.
+			 */
+			mtx_unlock(&ps->ps_mtx);
+		    if (thread_single(p, SINGLE_BOUNDARY) == 0) {
+				p->p_sig = sig;
+				(void)coredump(td);
+				/* XXX-LPT coredump() drops the lock, retake it. */
+				PROC_LOCK(p);
+				thread_single_end(p, SINGLE_BOUNDARY);
+			}
+			mtx_lock(&ps->ps_mtx);
+		}
 	} else {
 		/*
 		 * If we get here, the signal must be caught.
