include(`m4-lib/forloop.m4') dnl
include(`m4-lib/foreach.m4') dnl

define(`join', `$2`'foreach(`other_arg', (shift(shift($*))), `$1`'other_arg')')


ifdef(`ALLOCATORS',,`errprint(`Missing -D ALLOCATORS="..."') m4exit(1)')
ifelse(ALLOCATORS,,`errprint(`Empty macro definition -D ALLOCATORS="'ALLOCATORS`"') m4exit(1)')
define(`whitespace', `[ 	]+')
define(`allocs', (patsubst(patsubst(patsubst(ALLOCATORS, `^'whitespace, `'),
                           whitespace`$', `'),
                           whitespace, `,')))
undefine(`whitespace')

define(`allocs_cnt', 0)
define(`count_alloc', `define(`allocs_cnt', incr(allocs_cnt))')
foreach(`_', allocs, `count_alloc')
undefine(`count_alloc')

define(`aentry_flag_of', self->in_allocator_$1)
define(`achain_pos_of', self->allocator_chain_pos_$1)
define(`achain_len', self->allocator_chain_len)

define(`alloc_chain_fmt', forloop(`_', `1', eval(allocs_cnt - 1), `%d ')`%d')
define(`alloc_chain_fmt_args', `shift(foreach(`a', allocs, `, achain_pos_of(a)'))')


dnl DTrace script API ------------------------------------------------------ {{{
define(`ENTRY_OF_ALLOC',
pid$target::$2:`ifelse(index('FUNCS_MISSING_A_PROBE`, $2:entry), -1, entry, return)'
{
	aentry_flag_of($1) += 1;
	achain_len += aentry_flag_of($1) == 1;
	achain_pos_of($1) = aentry_flag_of($1) == 1 ? achain_len : 0;
})
define(`EXIT_OF_ALLOC',
pid$target::$2:`ifelse(index('FUNCS_MISSING_A_PROBE`, $2:return), -1, return, entry)'
{
	achain_pos_of($1) = aentry_flag_of($1) == 1 ? 0 : achain_len;
	achain_len -= aentry_flag_of($1) == 1;
	aentry_flag_of($1) -= 1;
})

dnl Note: ALLOC_CHAIN_FMT and ALLOC_CHAIN_FMT_ARGS are obsolete,
dnl use TRACE_CTXT instead
define(`ALLOC_CHAIN_FMT', | forloop(`c', `1', eval(allocs_cnt - 1), `%d ')`%d')
dnl XXX: Is there a way to define ALLOC_CHAIN_FMT_ARGS as a quoted string,
dnl rather than a macro that must be processed each time (e.g. using backtick.m4 ?)
define(`ALLOC_CHAIN_FMT_ARGS', `shift(foreach(`alloc', allocs, `, achain_pos_of(alloc)'))')

dnl define(`TRACE_CTXT_FMT', foreach(`f', (%d, %s, %d, alloc_chain_fmt), `\tf'))
define(`TRACE_CTXT_FMT', join(`\t', %d, %d, %d, alloc_chain_fmt))
define(`TRACE_CTXT_FMT_ARGS', `shift(foreach(`c', (timestamp, vtimestamp, tid,dnl
                                               alloc_chain_fmt_args), `, c'))')

dnl ------------------------------------------------------------------------ }}}
dnl DTrace script generation ----------------------------------------------- {{{
#pragma D option bufsize=5g
#pragma D option bufpolicy=switch
#pragma D option switchrate=50hz
#pragma D option dynvarsize=128m

foreach(`alloc', allocs, `self int patsubst(aentry_flag_of(alloc),self->,);
')
foreach(`alloc', allocs, `self int patsubst(achain_pos_of(alloc),self->,);
')
self int patsubst(achain_len, self->,);


`BEGIN
{
	wts_initial = walltimestamp;
	ts_initial = timestamp;
#define timestamp  (wts_initial + (timestamp - ts_initial))
}'

foreach(`alloc', allocs, `include(alloc.d)
')
dnl ------------------------------------------------------------------------ }}}
