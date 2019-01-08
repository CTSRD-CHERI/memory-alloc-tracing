#!/usr/bin/env perl
use strict;
use Time::HiRes qw( usleep time gettimeofday);
use File::stat;
use Cwd qw ( cwd );
use 5.010;

my $KB = 2**10;
my $MB = 2**20;
my $PAGE_SIZE = 4 * $KB;
my $COREDUMP_SIGNAL = 'SIGUSR2';
my $g_pid = $ARGV[0];
my ($g_time_s, $time_us) = gettimeofday();
my $cpu_ts = 0;

sub proc_vmstat {
	open my $ps, "-|", "procstat -v $g_pid";
	my $dsize_b = 0;

	my @header;
	if (my $header = <$ps>) {
		$_ = $header;
		#print;
		s/^\s+//;
		@header = split / +/, lc;
	}
	while (<$ps>) {
		#print;
		s/^\s+//;
		my @fields = split / +/, $_, 12;
		my %fields = map { $header[$_] => $fields[$_] } 0 .. $#fields;
		next if $fields{tp} !~ /^(df|ph|sw)/;
		next if $fields{prt} !~ /^rw./;

		#print;
		# Count the entire address range for (partially) swapped VM objects,
		# but only count resident pages for other VM object types.
		if ($fields{tp} eq 'sw') {
			$dsize_b += hex($fields{end}) - hex($fields{start});
		} else {
			$dsize_b += $fields{res} * $PAGE_SIZE;
		}
	}
	close $ps or return 0;

	my $dsize_kb = $dsize_b / $KB;
	my $dsize_mb = $dsize_b / $MB;
	$dsize_b;
}


sub proc_coredump {
	state $coredumps = 0;
	my @corefiles;

	system("kill -$COREDUMP_SIGNAL $g_pid") == 0 or return '';
	my $tried = 0;
	while (1) {
		sleep 1;
		@corefiles = grep -f && stat($_)->mtime >= $g_time_s, glob '*.core';
		last if @corefiles;
		die "$g_time_s\tCould not coredump process $g_pid" if ++$tried > 30;
	}

	$coredumps++;
	my $corefile = sprintf '%s-%03d', ($corefiles[0], $coredumps);
	rename @corefiles[0], $corefile or
	    die "Could not rename $corefiles[0] -> $corefile";
	$corefile;
}


my $slept_us = 0;
my $SLEEP_US_SHORT = 500000;
my $SLEEP_US_LONG = $SLEEP_US_SHORT * 60;
die "SLEEP_US_LONG=$SLEEP_US_LONG, must be multiple
     of SLEEP_US_SHORT=$SLEEP_US_LONG" if $SLEEP_US_LONG % $SLEEP_US_SHORT;

system("sudo sysctl kern.coredump_on_".lc($COREDUMP_SIGNAL)."=1 >/dev/null") == 0 or
    die "Cannot enable coredump-ing on signal $COREDUMP_SIGNAL";
system("sudo limits -P $g_pid -c 5g") == 0 or
    die "Cannot lift coredump size limit for process $g_pid";

# XXX-LPT: Consider launching process-coredump-samples.pl from here (run in parallel with the workload)
print "#timestamp-unix-ns\taddr-space-size-b\tcorefile\tcpu-time-ns\n";
while (my $size_b = proc_vmstat()) {
	my $do_coredump = ($slept_us % $SLEEP_US_LONG) == 0;
	my $corefile = $do_coredump ? proc_coredump() : '';

	printf "%d%06d000\t%d\t%s\t%d\n", ($g_time_s, $time_us, $size_b, $corefile, $cpu_ts);
	last if $do_coredump && !$corefile;

	usleep($SLEEP_US_SHORT);
	$slept_us += $SLEEP_US_SHORT;
	($g_time_s, $time_us) = gettimeofday();
}
