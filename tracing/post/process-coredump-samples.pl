#!/usr/bin/env perl
use strict;
use File::Basename;

my $my_dir = dirname($0);

my $sweep_latest = 0;
my $sz_from_coredump_latest = 0;
print '#', join("\t", qw ( timestamp-unix-ns addr-space-size-b-from-procstat
                addr-space-size-b-from-coredump sweep-amount-b)), "\n";
while (<>) {
	next if /^#/;
	my ($ts, $sz, $corefile) = split /\t/;
	chomp $corefile;
	if ($corefile ne '') {
		print "#$_";
		my ($sz_from_coredump, $sweep) = split / /, `$my_dir/proc-sweep-amount.pl $corefile`;
		die 'proc-sweep-amount failed' if !defined $sweep;
		$sweep_latest = $sweep;
		$sz_from_coredump_latest = $sz_from_coredump;
	}
	# XXX-LPT: Prefer the coredump measure of address-space size as it is
	# more likely what is needed, since it seems to be more consistent with
	# other measures, such as the amount of memory mapped by the allocator
	$sz = $sz_from_coredump_latest;
	$_ = sprintf "%d\t%d\t%d\n", ($ts, $sz, $sweep_latest);
} continue {
	print;
}
