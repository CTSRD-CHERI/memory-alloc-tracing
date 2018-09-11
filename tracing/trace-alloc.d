#!/usr/sbin/dtrace -Cs

#pragma D option bufsize=5g
#pragma D option bufpolicy=switch
#pragma D option switchrate=50hz
#pragma D option dynvarsize=128m

self int ustack_id;
bool ustack_ids_initd;
/* int ustack_ids[unsigned long, stack]; */

/* 
 * The aggregation is only necessary as there doesn't seem to be another way
 * to print all the keys.
 * XXX-LPT is this very slow? could be made faster with a single ustack() call
 * and an approximate this->usid that is greater or equal to the actual ID, but
 * less than the next actual ID.
 *
 * XXX-LPT cannot seem to use associative array keyed by ustack()
#define ustack_getid() \
	this->usid = ustack_ids[tid, ustack()]; \
	this->usid = this->usid ? this->usid : self->ustack_id++; \
	ustack_ids[tid, ustack()] = this->usid; \
	@ustack_ids[tid, ustack()] = min(this->usid)
 */
#define ustack_getid() \
	this->usid = self->ustack_id++; \
	@ustack_ids[tid, ustack()] = min(this->usid)

#define ustack_save(keys...) \
	@ustack_ids[keys, ustack()] = min(1)


BEGIN
{
	wts_initial = walltimestamp;
	ts_initial = timestamp;
#define timestamp  (wts_initial + (timestamp - ts_initial))
}
/*
END
{
	printf("# Stackframes key\n");
	printa(@ustack_ids);
}
*/

pid$target::malloc:entry
{
	self->malloc_arg0 = arg0;
}
pid$target::malloc:return
/ arg1 && self->malloc_arg0 && !self->using_malloc / {
	printf("\n%d %s(%d): %p", timestamp, probefunc, self->malloc_arg0, arg1);
	self->malloc_arg0 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}

pid$target::calloc:entry
{
	self->calloc_arg0 = arg0;
	self->calloc_arg1 = arg1;
	self->using_malloc = 1;
}
pid$target::calloc:return {
	self->using_malloc = 0;
}
pid$target::calloc:return
/ arg1 && self->calloc_arg0 && self->calloc_arg1 / {
	printf("\n%d %s(%d, %d): %p", timestamp, probefunc, self->calloc_arg0, self->calloc_arg1, arg1);
	self->calloc_arg0 = 0;
	self->calloc_arg1 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}

pid$target::aligned_alloc:entry
{
	self->aligned_alloc_arg0 = arg0;
	self->aligned_alloc_arg1 = arg1;
	self->using_malloc = 1;
}
pid$target::aligned_alloc:return {
	self->using_malloc = 0;
}
pid$target::aligned_alloc:return
/ arg1 && self->aligned_alloc_arg0 && self->aligned_alloc_arg1 / {
	printf("\n%d %s(%d, %d): %p", timestamp, probefunc, self->aligned_alloc_arg0, self->aligned_alloc_arg1, arg1);
	self->aligned_alloc_arg0 = 0;
	self->aligned_alloc_arg1 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}

pid$target::posix_memalign:entry
{
	self->posix_memalign_arg0 = (uintptr_t)arg0;
	self->posix_memalign_arg1 = arg1;
	self->posix_memalign_arg2 = arg2;
	self->using_malloc = 1;
}
pid$target::posix_memalign:return {
	self->using_malloc = 0;
}
pid$target::posix_memalign:return
/ arg1 == 0 && self->posix_memalign_arg1 && self->posix_memalign_arg2 / {
	allocd_addr_ptr = (void**)copyin(self->posix_memalign_arg0, sizeof(void*));
	printf("\n%d %s(%d, %d): %p %d %d", timestamp, probefunc, self->posix_memalign_arg1, self->posix_memalign_arg2, *allocd_addr_ptr, arg0, arg1);
	self->posix_memalign_arg0 = 0;
	self->posix_memalign_arg1 = 0;
	self->posix_memalign_arg2 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}


pid$target::realloc:entry
{
	self->realloc_arg0 = arg0;
	self->realloc_arg1 = arg1;
	self->using_malloc = 1;
	self->using_free = 1;
}
pid$target::realloc:return {
	self->using_malloc = 0;
	self->using_free = 0;
}
pid$target::realloc:return {
/ arg1 && self->realloc_arg0 && self->realloc_arg0 / {
	printf("\n%d %s(%p, %d): %p", timestamp, probefunc, self->realloc_arg0, self->realloc_arg1, arg1);
	self->realloc_arg0 = 0;
	self->realloc_arg1 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}


/* MAP_ANONYMOUS only */
pid$target::mmap:entry
{
	self->mmap_arg0 = arg0;
	self->mmap_arg1 = arg1;  /* length */
	self->mmap_arg2 = arg2;
	self->mmap_arg3 = arg3;
	self->mmap_arg4 = arg4;  /* fd */
	self->mmap_arg5 = arg5;
}
pid$target::mmap:return
/ (void*)arg1 != (void*)-1 && self->mmap_arg1 && (self->mmap_arg3 & 0x1000) / {
	this->ts = timestamp;
	/* ustack_save(tid, this->ts); */
	printf("\n%d %s(%p, %d, %x, %x, %d, %x): %p", this->ts, probefunc,
	       self->mmap_arg0, self->mmap_arg1, self->mmap_arg2, self->mmap_arg3,
		   self->mmap_arg4, self->mmap_arg5, arg1
		   );
	self->mmap_arg0 = 0;
	self->mmap_arg1 = 0;
	self->mmap_arg2 = 0;
	self->mmap_arg3 = 0;
	self->mmap_arg4 = 0;
	self->mmap_arg5 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}

pid$target::munmap:entry
{
	self->munmap_arg0 = arg0;
	self->munmap_arg1 = arg1;  /* length */
}
pid$target::munmap:return
/ !arg1 && self->munmap_arg1 / {
	this->ts = timestamp;
	/* ustack_save(tid, this->ts); */
	printf("\n%d %s(%p, %d): %p", this->ts, probefunc,
	       self->munmap_arg0, self->munmap_arg1, arg1
		   );
	self->munmap_arg0 = 0;
	self->munmap_arg1 = 0;
	ustack();
	/* this->do_ustack = 1; */
	/* printf("\n"); */
}


pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack();
	this->do_ustack = 0;
}

pid$target::free:entry
/ !self->using_free / {
	printf("\n%d %s(%p)\n", timestamp, probefunc, arg0);
	/* ustack(); */
}

/* ustack() sometimes fails, presumably due accessing badly-decoded stack frame addresses.
 * Try ustack() with various nframes argument. */
pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack(10);
	this->do_ustack = 0;
}
pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack(8);
	this->do_ustack = 0;
}
pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack(6);
	this->do_ustack = 0;
}
pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack(4);
	this->do_ustack = 0;
}
pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack(3);
	this->do_ustack = 0;
}
pid$target::malloc:return,
pid$target::calloc:return,
pid$target::realloc:return,
pid$target::aligned_alloc:return,
pid$target::posix_memalign:return,
pid$target::mmap:return,
pid$target::munmap:return
/ this->do_ustack / {
	ustack(2);
	this->do_ustack = 0;
}
