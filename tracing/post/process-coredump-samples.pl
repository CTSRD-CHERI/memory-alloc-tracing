#!/usr/bin/env perl
use strict;
use File::Basename;

my $my_dir = dirname($0);

my $sweep_latest = 0;
print '#', join("\t", qw ( timestamp-unix-ns addr-space-size-b sweep-amount-b)), "\n";
while (<>) {
	next if /^#/;
	my ($ts, $sz, $corefile) = split /\t/;
	chomp $corefile;
	if ($corefile ne '') {
		print "#$_";
		my $sweep = `$my_dir/proc-sweep-amount.pl $corefile`;
		die 'proc-sweep-amount failed' if !defined $sweep;
		$sweep_latest = $sweep;
	}
	$_ = sprintf "%d\t%d\t%d\n", ($ts, $sz, $sweep_latest);
} continue {
	print;
}
