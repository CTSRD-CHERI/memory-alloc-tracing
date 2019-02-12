diff --git a/usr/src/cddl/contrib/opensolaris/lib/libdtrace/common/dt_consume.c.orig b/usr/src/cddl/contrib/opensolaris/lib/libdtrace/common/dt_consume.c
index 98dc29a..67d731e 100644
--- a/usr/src/cddl/contrib/opensolaris/lib/libdtrace/common/dt_consume.c.orig
+++ b/usr/src/cddl/contrib/opensolaris/lib/libdtrace/common/dt_consume.c
@@ -1380,45 +1380,7 @@ dt_print_ustack(dtrace_hdl_t *dtp, FILE *fp, const char *format,
 		if ((err = dt_printf(dtp, fp, "%*s", indent, "")) < 0)
 			break;
 
-		if (P != NULL && Plookup_by_addr(P, pc[i],
-		    name, sizeof (name), &sym) == 0) {
-			(void) Pobjname(P, pc[i], objname, sizeof (objname));
-
-			if (pc[i] > sym.st_value) {
-				(void) snprintf(c, sizeof (c),
-				    "%s`%s+0x%llx", dt_basename(objname), name,
-				    (u_longlong_t)(pc[i] - sym.st_value));
-			} else {
-				(void) snprintf(c, sizeof (c),
-				    "%s`%s", dt_basename(objname), name);
-			}
-		} else if (str != NULL && str[0] != '\0' && str[0] != '@' &&
-		    (P != NULL && ((map = Paddr_to_map(P, pc[i])) == NULL ||
-		    (map->pr_mflags & MA_WRITE)))) {
-			/*
-			 * If the current string pointer in the string table
-			 * does not point to an empty string _and_ the program
-			 * counter falls in a writable region, we'll use the
-			 * string from the string table instead of the raw
-			 * address.  This last condition is necessary because
-			 * some (broken) ustack helpers will return a string
-			 * even for a program counter that they can't
-			 * identify.  If we have a string for a program
-			 * counter that falls in a segment that isn't
-			 * writable, we assume that we have fallen into this
-			 * case and we refuse to use the string.
-			 */
-			(void) snprintf(c, sizeof (c), "%s", str);
-		} else {
-			if (P != NULL && Pobjname(P, pc[i], objname,
-			    sizeof (objname)) != 0) {
-				(void) snprintf(c, sizeof (c), "%s`0x%llx",
-				    dt_basename(objname), (u_longlong_t)pc[i]);
-			} else {
-				(void) snprintf(c, sizeof (c), "0x%llx",
-				    (u_longlong_t)pc[i]);
-			}
-		}
+		(void) snprintf(c, sizeof (c), "0x%llx", (u_longlong_t)pc[i]);
 
 		if ((err = dt_printf(dtp, fp, format, c)) < 0)
 			break;
