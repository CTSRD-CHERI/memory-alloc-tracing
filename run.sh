#!/usr/bin/env bash
function on_err_stop_workload_process {
	err=$?
	run_duration=$((`date +%s` - $ts_start))
	test $run_duration -lt 30 && rm -rf $run_dir
	test $COPROC_PID && kill -s SIGKILL $COPROC_PID
	exit $err
}

function on_exit_echo_code {
	echo Exit $?
}

function print_help {
	echo "$0 -c config_file [executable]"
	echo "$0 executable"
}


# Parse command-line arguments
while getopts 'c:h' cmdline_opt $*; do
	case "$cmdline_opt" in
	c)
		config_file=`realpath $OPTARG`
		test -f $config_file || { echo No config file $config_file >&2; exit 1 ;}
		;;
	h)
		print_help
		exit 0
		;;
	esac
done
if [ -z "$config_file" ]; then
	test $# -gt 0 || { print_help; exit 1 ;}
	config_file=`realpath run-config/config-generic`
fi
echo Using config file $config_file
shift $((OPTIND - 1))


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


for d in runs
do
	test -d $d -o -h $d || mkdir $d
done


ts=`date '+%Y%m%d_%H%M%S'`
run_dir=${my_dir}/runs/$ts-$cfg_name
dtrace_script=trace-alloc.d
trace_file=$cfg_name-malloc-trace-$ts
samples_file=$cfg_name-size-samples-$ts
run_info_file=$cfg_name-run-info-$ts
mkdir -p ${run_dir}
cd ${run_dir}

# Save env
env > ${run_dir}/env

# Ask for sudo privilege before starting (required by the dtrace command)
sudo echo -n
# Ensure the required dtrace modules are loaded
sudo dtrace -ln 'pid:::entry' >/dev/null 2>&1
sudo sysctl kern.dtrace.buffer_maxsize=`expr 10 \* 1024 \* 1024 \* 1024`

# Start the workload coprocess (should be suspended), redirecting
# its stdout/stderr to ours
{ coproc $my_dir/workload/$cfg_workload/run-$cfg_workload 2>&4 ;} 4>&2
sleep 6 && read -u ${COPROC[0]} workload_pid
# Throttle down the workload process to avoid trace drops
# XXX-LPT: tweak this knob if the trace shows sample drops
#    TODO: pull this out as a config e.g. pcpu_limit ($cfg_pcpu_limit)
sudo rctl -a process:$workload_pid:pcpu:deny=25


# Generate the DTrace script
m4 -D ALLOCATORS="$cfg_allocators" -I $my_dir/tracing $my_dir/tracing/trace-alloc.m4 > $dtrace_script
# Report any trace probes that are not there to trace
sudo dtrace -l -qw -Cs $dtrace_script -p $workload_pid 2>${trace_file}-err >&2
# Permit destructive actions in dtrace (-w) to not abort due to
# systemic unresponsiveness induced by heavy tracing
sudo dtrace -Z -qw -Cs $dtrace_script -p $workload_pid \
                 2>>${trace_file}-err | $my_dir/tracing/normalise-trace.pl >${trace_file} &
dtrace_pid=$!
# Send the start signal to the workload
sleep 2 && kill -s SIGUSR1 $COPROC_PID
$my_dir/tracing/proc-memstat.pl $workload_pid >${samples_file} 2>${samples_file}-err &
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
    $my_dir/tracing/post/process-coredump-samples.pl <$samples_file \
                                           >$samples_file-processing
	_retry=300
done && mv $samples_file-processing $samples_file ;} &

# Post-process
wait $COPROC_PID $workload_pid
wait $dtrace_pid
test -d ${run_dir} &&
  $my_dir/tracing/post/merge-samples-and-trace.sh $samples_file $trace_file >${run_info_file} &&
  rm -f $samples_file $trace_file
