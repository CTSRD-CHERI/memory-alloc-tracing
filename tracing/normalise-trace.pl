#!/usr/bin/env perl

# This parser script should post-process DTrace output to a single tab-separated line per record:
# ts	callstack	request (malloc/calloc/realloc/aligned_alloc/free)	args	result (addr/na)

my %alloc_sites;
my %alloc_site_for_addr;

print '#', join("\t", qw ( timestamp-unix-ns callstack tid name args result)), "\n";
while (<>) {
	my $call_trace = '^([0-9]+)\s+(\w+)';
	my $arg_trace = '\(([0-9a-f]+)' . ('(?:,\s+([0-9a-f]+))?' x 5) . '\)';
	my $result_trace = '(?::\s+([0-9a-f]+))?';
	my $tid_trace = '\s+([0-9]+)$';   # Thread ID
	if (/$call_trace$arg_trace$result_trace$tid_trace/) {
		my ($ts, $call) = ($1, $2);
		my @args = ($3, $4, $5, $6, $7, $8);
		my $res = $9;
		my $tid = $10;
		my $stack = "";
		while ((my $stack_line = <>) ne "\n") {
			last if !defined($stack_line);
			chomp $stack_line;
			$stack_line =~ s/^\s+/SPACE/;
			$stack_line =~ s/\s+/---/g;
			$stack .= $stack_line;
		}
		$call =~ s/__//;
		chomp $stack;
		$stack =~ s/^SPACE//;
		$stack =~ s/SPACE/ /g;
		print join "\t", $ts, $stack, $tid, $call, join(" ", @args), $res;
		print "\n";
	}
}
