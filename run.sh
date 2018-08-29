#!/usr/bin/env bash
function on_err_stop_workload_process {
	eval "
	run_duration=\$((`date +%s` - $ts_start))
	test \$run_duration -gt 30 || rm -rf $run_dir
	test $COPROC_PID && kill -s SIGKILL $COPROC_PID
	exit $?
	"
}

function on_exit_echo_code {
	echo Exit $?
}

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
run_dir=${my_dir}/runs/$ts-chromium
trace_file=chromium-malloc-trace-$ts
samples_file=chromium-size-samples-$ts
run_info_file=chromium-run-info-$ts
mkdir -p ${run_dir}
cd ${run_dir}

# Save env
env > ${run_dir}/env

# Ask for sudo privilege before starting (required by the dtrace command)
sudo echo -n
# Ensure the required dtrace modules are loaded
sudo dtrace -ln 'pid:::entry' >/dev/null 2>&1
sudo sysctl kern.dtrace.buffer_maxsize=`expr 10 \* 1024 \* 1024 \* 1024`

# Start the workload coprocess (suspended), redirecting its stderr to
# our stdout
echo Using `which chrome`
{ coproc $my_dir/workload/chromium-driver.py --chrome-binary=`which chrome` \
                 --chrome-stdout=${run_dir}/chromium-out-$ts 2>&3 ;} 3>&1
                 # XXX | tee ${run_dir}/chromium-driver-$ts-err
sleep 4 && chromium_pid=`pgrep -f browser-startup-dialog` || \
                 { echo Could not get workload PID; test ;}

# Permit destructive actions in dtrace (-w) to not abort due to
# systemic unresponsiveness induced by heavy tracing
sudo dtrace -qw -Cs $my_dir/tracing/trace-alloc.d -p $chromium_pid \
                 >${trace_file} 2>${trace_file}-err &
dtrace_pid=$!
# Send the start signal to the workload driver
sleep 2 && kill -s SIGUSR1 $chromium_pid
$my_dir/tracing/proc-memstat.pl $chromium_pid >${samples_file} 2>${samples_file}-err &
proc_memstat_pid=$!

# Cross-check the pid obtained externally with the one reported by the
# workload driver
read -u ${COPROC[0]} chromium_pid_actual
test $chromium_pid = $chromium_pid_actual ||
     { echo "Anticipated PID mismatches actual PID ($chromium_pid != $chromium_pid_actual)"; test ;}

# Disable exiting on any non-zero code, the workload might have usefully run for long enough
set +e

wait %?workload

# Post-process
wait $proc_memstat_pid
test $? -eq 0 -o $? -eq 127 && $my_dir/tracing/post/process-coredump-samples.pl <$samples_file >/tmp/$samples_file
test $? -eq 0 && mv /tmp/$samples_file $samples_file

wait $dtrace_pid
# TODO: make normalise-trace.pl aware of callstack IDs;
# normalise stage left disabled as it discards them, loosing data
#| tracing/normalise-trace.pl &
test -d ${run_dir} && sort -m -k 1n ${trace_file} ${samples_file} >${run_info_file}
