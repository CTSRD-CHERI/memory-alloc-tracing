/* 
 * This module file is included and macro-processed along with other DTrace
 * script module files by trace-alloc.m4.
 * See trace-alloc.m4 for the module-facing API for integrating modules
 * within this framework.
 */

pid$target::malloc:entry
{
	ENTRY_OF_ALLOC(malloc);
	self->malloc_arg0 = arg0;
}
pid$target::malloc:return
/ arg1 && self->malloc_arg0 && !self->using_malloc / {
	printf("\nmalloc(%d): %p TRACE_CTXT_FMT", self->malloc_arg0, arg1,
	       TRACE_CTXT_FMT_ARGS);
	ustack();  /* ustack() adds '\n' at the start and end of the string */
}
pid$target::malloc:return {
	self->malloc_arg0 = 0;
	EXIT_OF_ALLOC(malloc);
}

pid$target::calloc:entry
{
	ENTRY_OF_ALLOC(malloc);
	self->calloc_arg0 = arg0;
	self->calloc_arg1 = arg1;
	self->using_malloc = 1;
}
pid$target::calloc:return
/ arg1 && self->calloc_arg0 && self->calloc_arg1 / {
	printf("\ncalloc(%d, %d): %p TRACE_CTXT_FMT",
	       self->calloc_arg0, self->calloc_arg1, arg1,
		   TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::calloc:return {
	self->using_malloc = 0;
	self->calloc_arg0 = 0;
	self->calloc_arg1 = 0;
	EXIT_OF_ALLOC(malloc);
}

pid$target::aligned_alloc:entry
{
	ENTRY_OF_ALLOC(malloc);
	self->aligned_alloc_arg0 = arg0;
	self->aligned_alloc_arg1 = arg1;
 	self->using_malloc = 1;
}
pid$target::aligned_alloc:return
/ arg1 && self->aligned_alloc_arg0 && self->aligned_alloc_arg1 / {
	printf("\naligned_alloc(%d, %d): %p TRACE_CTXT_FMT",
	       self->aligned_alloc_arg0, self->aligned_alloc_arg1, arg1,
		   TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::aligned_alloc:entry {
 	self->using_malloc = 0;
	self->aligned_alloc_arg0 = 0;
	self->aligned_alloc_arg1 = 0;
	EXIT_OF_ALLOC(malloc);
}

pid$target::valloc:entry
{
	ENTRY_OF_ALLOC(malloc);
	self->valloc_arg0 = arg0;
	self->using_malloc = 1;
}
pid$target::valloc:return
/ arg1 && self->valloc_arg0 / {
	printf("\nvalloc(%d): %p TRACE_CTXT_FMT", self->valloc_arg0, arg1, 
	       TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::valloc:return {
	self->using_malloc = 0;
	self->valloc_arg0 = 0;
	EXIT_OF_ALLOC(malloc);
}

pid$target::posix_memalign:entry
{
	ENTRY_OF_ALLOC(malloc);
	self->posix_memalign_arg0 = (uintptr_t)arg0;
	self->posix_memalign_arg1 = arg1;
	self->posix_memalign_arg2 = arg2;
	self->using_malloc = 1;
}
pid$target::posix_memalign:return
/ arg1 == 0 && self->posix_memalign_arg1 && self->posix_memalign_arg2 / {
	allocd_addr_ptr = (void**)copyin(self->posix_memalign_arg0, sizeof(void*));
	printf("\nposix_memalign(%d, %d): %p TRACE_CTXT_FMT",
	       self->posix_memalign_arg1, self->posix_memalign_arg2, *allocd_addr_ptr,
		   TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::posix_memalign:return {
	self->using_malloc = 0;
	self->posix_memalign_arg0 = 0;
	self->posix_memalign_arg1 = 0;
	self->posix_memalign_arg2 = 0;
	EXIT_OF_ALLOC(malloc);
}


pid$target::realloc:entry
{
	ENTRY_OF_ALLOC(malloc);
	self->realloc_arg0 = arg0;
	self->realloc_arg1 = arg1;
	self->using_malloc = 1;
	self->using_free = 1;
}
pid$target::realloc:return
/ (self->realloc_arg0 || self->realloc_arg1) &&
  (!self->realloc_arg1 || arg1) / {
	printf("\nrealloc(%p, %d): %p TRACE_CTXT_FMT",
	       self->realloc_arg0, self->realloc_arg1, arg1,
	       TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::realloc:return {
	self->using_malloc = 0;
	self->using_free = 0;
	self->realloc_arg0 = 0;
	self->realloc_arg1 = 0;
	EXIT_OF_ALLOC(malloc);
}


pid$target::free:entry {
	ENTRY_OF_ALLOC(malloc);
}
pid$target::free:entry
/ arg0 && !self->using_free / {
	printf("\nfree(%p) TRACE_CTXT_FMT", arg0, TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::free:return {
	EXIT_OF_ALLOC(malloc);
}
