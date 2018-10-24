#!/usr/bin/env perl
use strict;
use feature qw ( say );
use File::Basename;
#use Carp::Assert;

# $MEM_TO_MAP is the memory-to-map ratio in bytes-per-bit of the map we should be using.
# Adjust this to a value that's a multiple of 64 used by the .vecbin file, e.g. 4096
# to look at pages of memory.
my $MEM_TO_MAP = 4096;
$MEM_TO_MAP >= 64 or die 'Must have greater memory-to-map ratio than the .vecbin
                          input-file ratio of 64:1';
$MEM_TO_MAP % 64 == 0 or die 'Must have memory-to-map ratio multiple of the .vecbin
                              input-file ratio of 64:1';
# $MIN_SKIP_B is the least amount of bytes that should be skipped.
my $MIN_SKIP_B = 4 * 1024;
$MIN_SKIP_B >= 1 * $MEM_TO_MAP or die "Can only look for $MEM_TO_MAP (MEM_TO_MAP)
                                       minimum bytes to skip";
my $MIN_SKIP_MAP = $MIN_SKIP_B / $MEM_TO_MAP;

my $my_dir = dirname($0);
my $corefile = $ARGV[0];
if (!-e "$corefile.vecbin") {
	my $pypy_cmd = `which pypy3`;
	chomp $pypy_cmd;
	system("$pypy_cmd $my_dir/pycdump-scan/pycdump-scan.py --dump-ptr-vector $corefile >/dev/null 2>&1") == 0 or
	      die "Cannot compute .vecbin from $corefile (pycdump-scan exited $?)";
}
open my $fh, '<', "$corefile.vecbin";
binmode $fh, ':raw';
$/ = undef;
my $mem_map = <$fh>;
#say length($mem_map);

my $map_to_map = $MEM_TO_MAP / 64;
my $mem_map_len = length($mem_map) / $map_to_map;
my @mem_map = map $_ != 0 ? ord('1') : ord('0'), unpack "b$map_to_map" x $mem_map_len, $mem_map;
$mem_map = pack 'c' x $mem_map_len, @mem_map;
#say $mem_map;

my @skips = ($mem_map =~ m/0{$MIN_SKIP_MAP,}/g);
#say scalar @skips;
my $skip = 0;
map { $skip += length } @skips;
my $skip_total_b = $skip * $MEM_TO_MAP;
my $mem_total_b = $mem_map_len * $MEM_TO_MAP;
my $sweep_total_b = $mem_total_b - $skip_total_b;
say $mem_total_b, ' ', $sweep_total_b;
