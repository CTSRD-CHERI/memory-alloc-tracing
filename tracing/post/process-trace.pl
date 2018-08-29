#!/usr/bin/env perl

# This parser script should post-process DTrace output to a single tab-separated line per record:
# ts	callstack	request (malloc/calloc/realloc/aligned_alloc/free)	args	result (addr/na)
#
# TODO:
# It should also read the legend which maps call sites to IDs that are unique per thread,
# and use it to decode the IDs back to call sites.  The DTrace script must code call sites to IDs
# so that they can be printed atomically, as opposed to the multi-line call sites whose lines can
# get mangled due to multi-core races.
#

my $csid = 0;
my @callstacks;
my %callstack_to_csid;
my %ts_tid_to_callstack;

my $tid_trace = '\s+([0-9]+)';
my $ts_trace = '\s+([0-9]+)';
open my $fh, '<', $ARGV[0] or die "Cannot open $ARGV[0]: $!";
while (<$fh>) {
	if (/^$tid_trace$ts_trace$/) {
		my ($ts, $tid) = ($2, $1);

		my $cs = "";
		my $csl;
		while (($csl = <$fh>) && $csl !~ /^\s+1$/) {
			chomp $csl;
			$csl =~ s/^\s+/SPACE/;
			$csl =~ s/\s+/---/g;
			$cs .= $csl;
		}
		chomp $cs;
		$cs =~ s/^SPACE//;
		$cs =~ s/SPACE/ /g;
		if (!defined $callstack_to_csid{$cs}) {
			push @callstacks, {callstack => $cs, refd => undef,
			                   #occurred => 0
							   };
			$callstack_to_csid{$cs} = $#callstacks;
			#print join("\t", $csid, $cs), "\n";
		}
		$ts_tid_to_callstack{"$ts\_$tid"} = $callstacks[$callstack_to_csid{$cs}];
		# XXX-LPT remove indirection
		#$callstacks[$callstack_to_csid{$cs}]->{occurred}++;
	}
}
close $fh;
#print join("\t", $_, $callstacks[$_]->{cs};

my %no_cs = (callstack => '', refd => '');
my $out_line_no = 0;
open my $fh, '<', $ARGV[0] or die "Cannot open $ARGV[0]: $!";
print '#', join("\t", qw ( timestamp-unix-ns callstack name args result)), "\n";
$out_line_no++;
while (<$fh>) {
	my $call_trace = '^([0-9]+)\s+([0-9]+)?\s+(\w+)';
	my $arg_trace = '\(([0-9a-f]+)' . ('(?:,\s+([0-9a-f]+))?' x 5) . '\)';
	my $result_trace = '(?::\s+([0-9a-f]+))?';
	if (/$call_trace(.*)/) {
		my ($ts, $tid, $call) = ($1, $2, $3);
		#my @args = ($4, $5, $6, $7, $8, $9);
		#my $res = $10;
		my $rest = $4;
		my $cs = $ts_tid_to_callstack{"$ts\_$tid"} // \%no_cs;
		$call =~ s/__//;
		#print $cs->{refd}, ' # ', $cs->{callstack}, "\n";
		#print join("\t", $ts, defined($cs->{refd}) ? $cs->{refd} : $cs->{callstack}, $call), $rest, "\n";
		print join("\t", $ts, $cs->{callstack}, $call), $rest, "\n";
		$out_line_no++;
		$cs->{refd} = "^$out_line_no" if !defined $cs->{refd};
	}
}
close $fh;
