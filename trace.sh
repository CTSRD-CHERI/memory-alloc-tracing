#!/usr/bin/env bash
function on_err_stop_workload_process {
	err=$?
	run_duration=$((`date +%s` - $ts_start))
	test $run_duration -lt 30 && rm -rf $run_dir
	test "$COPROC_PID" && kill -s SIGKILL $COPROC_PID
	test "$proc_memstat_pid" && kill -s SIGKILL $proc_memstat_pid
	test "$process_samples_pid" && kill -s SIGKILL $process_samples_pid
	test "$monitor_drops_pid" && kill -s SIGKILL $monitor_drops_pid
	exit $err
}

function on_exit_echo_code {
	echo Exit $?
}

function print_help {
	echo "$0 executable"
	echo "$0 -c config_file [executable]"
	printf "%${#0}s -h  Help: print this help and exit\n"
	printf "%${#0}s -q  Quiet: do not echo commands as they are executed\n"
	printf "%${#0}s -t T  Throttle the workload process to T%% of CPU time usage.\n"
	printf "%${#0}s       Defaults to 10%%.  Use this option to adjust the intensity of\n"
	printf "%${#0}s       the workload process to avoid DTrace dropping samples to cope, or\n"
	printf "%${#0}s       to allow the workload process to run faster.\n"
}

function echo_commands_on {
	if [ -z "$cfg_quiet" ]; then
		set -x
	fi
}
function echo_commands_off {
	set +x
}
function echo_command {
	if [ -z "$cfg_quiet" ]; then
		echo + $* >&2
	fi
}

# Parse command-line arguments
while getopts 'c:hqt:' cmdline_opt $*; do
	case "$cmdline_opt" in
	c)
		config_file=`realpath $OPTARG`
		test -f $config_file || { echo No config file $config_file >&2; exit 1 ;}
		;;
	h)
		print_help
		exit 0
		;;
	q)
		export cfg_quiet='true'
		;;
	t)
		cfg_pcpu_limit=`expr $OPTARG % 100`
		;;
	esac
done
shift $((OPTIND - 1))

# Command-line argument defaults
if [ -z "$config_file" ]; then
	test $# -gt 0 || { print_help; exit 1 ;}
	config_file=`realpath run-config/config-generic`
fi
if [ -z "$cfg_pcpu_limit" ]; then
	cfg_pcpu_limit=10
fi

echo Using config file $config_file
echo Throttling workload proces to $cfg_pcpu_limit% CPU time

# Parse the config file
while read name val; do
	export "cfg_$name"="$val"
done < $config_file
# Configs missing the "name" key get it from the first non-option argument,
# which is interpreted as an executable file name, or from the config
# filename if there is no non-option argument
if [ -z "$cfg_name" ]; then
	test $# -gt 0 && cfg_name=`basename $1` || cfg_name=`basename $config_file`
fi


# Cause any non-zero exit code to stop the script (e.g. from the test cmd),
# and handle this by stopping the workload coprocess. Handle SIGINT similarly
set -e && trap on_err_stop_workload_process ERR SIGINT
trap on_exit_echo_code EXIT

ts_start=`date +%s`
my_dir=`dirname $0`
my_dir=`cd $my_dir && pwd`
my_os=`uname -s`


# Initialise fresh repository clones
for d in runs
do
	test -d $d -o -h $d || mkdir $d
done

if git submodule status | grep -q '^-'; then
	git submodule init
	git submodule update
fi


ts=`date '+%Y%m%d_%H%M%S'`
run_dir=${my_dir}/runs/$ts-$cfg_name
dtrace_script=trace-alloc.d
trace_file=$cfg_name-malloc-trace-$ts
samples_file=$cfg_name-size-samples-$ts
run_info_file=$cfg_name-run-info-$ts
( echo_commands_on
mkdir -p ${run_dir}
)
echo_command cd ${run_dir}
cd ${run_dir}

# Save env
env > ${run_dir}/env

# Ask for sudo privilege before starting (required by the dtrace command)
sudo echo -n
# Ensure the required dtrace modules are loaded
sudo dtrace -ln 'pid:::entry' >/dev/null 2>&1
( echo_commands_on
sudo sysctl -i kern.dtrace.buffer_maxsize=10737418240  # 10 GiB
)

# Start the workload coprocess (should be suspended), redirecting
# its stdout/stderr to ours
echo_command $my_dir/workload/$cfg_workload/run-$cfg_workload $*
{ coproc $my_dir/workload/$cfg_workload/run-$cfg_workload $* 2>&4 ;} 4>&2
sleep 6 && read -u ${COPROC[0]} workload_pid
echo Workload PID: $workload_pid
# Throttle down the workload process to avoid trace drops
case ${my_os,,} in
	freebsd)
		( echo_commands_on
		sudo rctl -a process:$workload_pid:pcpu:deny=$cfg_pcpu_limit
		)
		;;
	darwin)
		cpulimit_max_pcpu=`cpulimit -h | grep 'percentage of cpu allowed' | egrep -o '[1-9][0-9]+'`
		( echo_commands_on
		sudo cpulimit -p $workload_pid \
		              -l $(($cfg_pcpu_limit * $cpulimit_max_pcpu / 100)) >/dev/null &
		)
		;;
	*)
		echo Don\'t know how to throttle down the workload process on ${my_os} >&2
		;;
esac

( echo_commands_on
# Generate the DTrace script
m4 -D ALLOCATORS="$cfg_allocators" -I $my_dir/tracing $my_dir/tracing/trace-alloc.m4 > $dtrace_script
# Report any trace probes that are not there to trace
sudo dtrace -l -qw -Cs $dtrace_script -p $workload_pid 2>${trace_file}-err >&2
)
# Regenerate the DTrace script adjusting for the missing entry or return probes
funcs_missing_a_probe=`cat ${trace_file}-err | sed -n -e \
's/.*'\
':\([_a-zA-Z0-9]\{1,\}\)'\
':\([_a-zA-Z0-9]\{1,\}\)'\
':[[:space:]]\{1,\}No probe matches description$'\
'/\1:\2 \1/p' | egrep ':(entry|return) ' | sort | uniq | uniq -u -f 1 | cut -d ' ' -f 1`
m4 -D ALLOCATORS="$cfg_allocators" -D FUNCS_MISSING_A_PROBE="$funcs_missing_a_probe" \
   -I $my_dir/tracing $my_dir/tracing/trace-alloc.m4 >$dtrace_script

# Permit destructive actions in dtrace (-w) to not abort due to
# systemic unresponsiveness induced by heavy tracing
sudo dtrace -Z -qw -Cs $dtrace_script -p $workload_pid \
                 2>>${trace_file}-err | $my_dir/tracing/normalise-trace.pl >${trace_file} &
dtrace_pid=$!
# Send the start signal to the workload driver
sleep 2 && kill -s SIGUSR1 $COPROC_PID
( echo_commands_on
$my_dir/tracing/proc-memstat.pl $workload_pid >${samples_file} 2>${samples_file}-err &
)
proc_memstat_pid=$!

# Disable exiting on any non-zero code, the workload might have usefully run for long enough
set +e

# Process the samples file until the producer (the proc-memstat sampler) stops
# XXX-LPT: this would best be hidden away into a proc-memstat driver script
{
_retry=30;
while kill -0 $proc_memstat_pid >/dev/null 2>/dev/null
do
    sleep $_retry
	( echo_commands_on
    $my_dir/tracing/post/process-coredump-samples.pl <$samples_file \
                                           >$samples_file-processing
	)
	_retry=300
done && mv $samples_file-processing $samples_file ;} &
process_samples_pid=$!

tail -f ${trace_file}-err > >(grep 'drops on CPU') &
monitor_drops_pid=$!

# Post-process
wait $COPROC_PID
wait $dtrace_pid
kill $monitor_drops_pid
wait $process_samples_pid
( echo_commands_on
test -d ${run_dir} &&
  $my_dir/tracing/post/merge-samples-and-trace.sh $samples_file $trace_file >${run_info_file} &&
  rm -f $samples_file $trace_file
)
