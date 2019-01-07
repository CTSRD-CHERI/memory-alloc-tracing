/* 
 * This module file is included and macro-processed along with other DTrace
 * script module files by trace-alloc.m4.
 * See trace-alloc.m4 for the module-facing API for integrating modules
 * within this framework.
 */

pid$target::mmap:entry
{
	ENTRY_OF_ALLOC(mmap);
	self->mmap_arg0 = arg0;
	self->mmap_arg1 = arg1;  /* length */
	self->mmap_arg2 = arg2;
	self->mmap_arg3 = arg3;
	self->mmap_arg4 = arg4;  /* fd */
	self->mmap_arg5 = arg5;
}
/* MAP_ANONYMOUS only */
pid$target::mmap:return
/ (void*)arg1 != (void*)-1 && self->mmap_arg1 && (self->mmap_arg3 & 0x1000) / {
	this->ts = timestamp;
	/* ustack_save(tid, this->ts); */
	printf("\nmmap(%p, %d, %x, %x, %d, %x): %p TRACE_CTXT_FMT",
	       self->mmap_arg0, self->mmap_arg1, self->mmap_arg2, self->mmap_arg3,
		   self->mmap_arg4, self->mmap_arg5, arg1, TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::mmap:return {
	self->mmap_arg0 = 0;
	self->mmap_arg1 = 0;
	self->mmap_arg2 = 0;
	self->mmap_arg3 = 0;
	self->mmap_arg4 = 0;
	self->mmap_arg5 = 0;
	EXIT_OF_ALLOC(mmap);
}

pid$target::munmap:entry
{
	ENTRY_OF_ALLOC(mmap);
	self->munmap_arg0 = arg0;
	self->munmap_arg1 = arg1;  /* length */
}
pid$target::munmap:return
/ !arg1 && self->munmap_arg1 / {
	this->ts = timestamp;
	/* ustack_save(tid, this->ts); */
	printf("\nmunmap(%p, %d): %p TRACE_CTXT_FMT",
	       self->munmap_arg0, self->munmap_arg1, arg1,
		   TRACE_CTXT_FMT_ARGS);
	ustack();
}
pid$target::munmap:entry {
	self->munmap_arg0 = 0;
	self->munmap_arg1 = 0;
	EXIT_OF_ALLOC(mmap);
}
