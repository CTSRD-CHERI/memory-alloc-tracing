#!/usr/bin/env perl

# This parser script should post-process DTrace output to a single tab-separated line per record:
# ts	callstack	request (malloc/calloc/realloc/aligned_alloc/free)	args	result (addr/na)

my %threads;
my @allocators = map ucfirst, (split / /, $ENV{'cfg_allocators'});
my $cpu_ts = 0;

print '@record-type:', join("\t", qw ( call-trace timestamp-unix-ns callstack tid name args
                            result alloc-stack cpu-time-ns )), "\n";
while (<>) {
	my $call_trace = '^(\w+)';
	my $args_trace = '\((-?[0-9a-f]+\s*' . '(?:,\s*-?[0-9a-f]+)*)\)';
	my $result_trace = '(?::\s*(-?[0-9a-f]+))?';

	my $ts_trace = '([0-9]+)';
	my $cpu_ts_trace = '([0-9]+)';
	my $tid_trace = '([0-9]+)';   # Thread ID
	my $alloc_chain_trace = '([0-9]+(?:\s+[0-9]+)*)';
	my $ctxt_trace = join "\t", $ts_trace, $cpu_ts_trace, $tid_trace, $alloc_chain_trace;

	if (/$call_trace$args_trace$result_trace\s*$ctxt_trace/) {
		my ($call, $args, $res) = ($1, $2, $3);
		my $ts = $4;
		my $cpu_ts_of_thrd = $5;
		my $tid = $6;
		my $alloc_chain_encoded = $7;
		$args =~ s/\s*,\s*/ /g;

		my $stack = "";
		while ((my $stack_line = <>) ne "\n") {
			last if !defined($stack_line);
			chomp $stack_line;
			$stack_line =~ s/^\s+/SPACE/;
			$stack_line =~ s/\s+/---/g;
			$stack .= $stack_line;
		}
		chomp $stack;
		$stack =~ s/^SPACE//;
		$stack =~ s/SPACE/ /g;

		my $thread = $threads{$tid} // {cpu_ts_last => 0};
		$cpu_ts += $cpu_ts_of_thrd - $thread->{cpu_ts_last};
		$thread->{cpu_ts_last} = $cpu_ts_of_thrd;
		$threads{$tid} = $thread;

		my @alloc_chain_encoded = split / /, $alloc_chain_encoded;
		my @alloc_chain;
		foreach (0..$#allocators) {
			my $alloc_pos = $alloc_chain_encoded[$_];
			if ($alloc_pos > 0) {
				$alloc_chain[$alloc_pos - 1] = $allocators[$_];
			}
		}
		$alloc_stack = join " ", reverse @alloc_chain;

		print join "\t", 'call-trace', $ts, $stack, $tid, $call, $args, $res,
		                 $alloc_stack, $cpu_ts;
		print "\n";
	}
}
