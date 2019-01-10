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

# Parse the config file passed via the command-line
if [ $# -gt 0 ] && [ -f $1 ]; then
	echo Using config file `realpath $1`
	while read name val; do
		export "cfg_$name"="$val"
	done < $1
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
sudo rctl -a process:$workload_pid:pcpu:deny=25

# Generate the DTrace script
m4 -D ALLOCATORS="$cfg_allocators" -I $my_dir/tracing $my_dir/tracing/trace-alloc.m4 > $dtrace_script
# Permit destructive actions in dtrace (-w) to not abort due to
# systemic unresponsiveness induced by heavy tracing
sudo dtrace -qw -Cs $dtrace_script -p $workload_pid \
                 2>${trace_file}-err | $my_dir/tracing/normalise-trace.pl >${trace_file} &
dtrace_pid=$!
# Send the start signal to the workload
sleep 2 && kill -s SIGUSR1 $workload_pid
$my_dir/tracing/proc-memstat.pl $workload_pid >${samples_file} 2>${samples_file}-err &
proc_memstat_pid=$!

# Disable exiting on any non-zero code, the workload might have usefully run for long enough
set +e

# Process the samples file until the producer (the proc-memstat sampler) stops
{
while kill -0 $proc_memstat_pid >/dev/null 2>/dev/null
do
    sleep 300
    $my_dir/tracing/post/process-coredump-samples.pl <$samples_file \
                                           >$samples_file-processing
done && mv $samples_file-processing $samples_file ;} &

# Post-process
wait $COPROC_PID
wait $dtrace_pid
test -d ${run_dir} &&
  $my_dir/tracing/post/merge-samples-and-trace.sh $samples_file $trace_file >${run_info_file}
