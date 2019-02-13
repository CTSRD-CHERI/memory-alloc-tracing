#!/usr/bin/env perl
use strict;
use File::Basename;

my $my_dir = dirname($0);

my $sweep_latest = 0;
my $sz_from_coredump_latest = 0;
print '@record-type:', join("\t", qw ( aspace-sample timestamp-unix-ns addr-space-size-b
                                  sweep-amount-b cpu-time-ns )), "\n";
while (<>) {
	next if /^#/;
	if (/^\@record-type:/) { $_ = "#$_"; next; }
	my ($rtype, $ts, $sz, $corefile) = split /\t/;
	my $cpu_ts = 0;
	chomp $corefile;
	if ($corefile ne '') {
		print "#$_";
		my ($sz_from_coredump, $sweep) = split / /, `$my_dir/proc-sweep-amount.pl $corefile`;
		die 'proc-sweep-amount failed' if !defined $sweep;
		$sweep_latest = $sweep;
		$sz_from_coredump_latest = $sz_from_coredump;
		unlink $corefile;
	}
	# XXX-LPT: Prefer the coredump measure of address-space size over the
	# one from procstat.  It is more likely what is needed, since it seems
	# to be more consistent with other measures, such as the amount of memory
	# mapped by the allocator
	$sz = $sz_from_coredump_latest;
	$_ = sprintf "aspace-sample\t%d\t%d\t%d\t%d\n", ($ts, $sz, $sweep_latest, $cpu_ts);
} continue {
	print;
}
