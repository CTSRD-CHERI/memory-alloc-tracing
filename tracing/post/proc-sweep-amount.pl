#!/usr/bin/env perl
use strict;
use feature qw ( say );
use File::Basename;
#use Carp::Assert;

# XXX-LPT: Consider moving this script to a function within process-coredump-samples.pl

# $MEM_TO_MAP is the memory-to-map ratio in bytes-per-bit of the map we should be using.
# Adjust this to a value that's a multiple of 64 used by the .vecbin file, e.g. 4096
# to look at pages of memory.
my $MEM_TO_MAP = 4096;
$MEM_TO_MAP >= 64 or die 'Must have greater memory-to-map ratio than the .vecbin
                          input-file ratio of 64:1';
$MEM_TO_MAP % 64 == 0 or die 'Must have memory-to-map ratio multiple of the .vecbin
                              input-file ratio of 64:1';

my $my_dir = dirname($0);
my $corefile = $ARGV[0];
if (!-e "$corefile.vecbin") {
	my $pypy_cmd = `which pypy3`;
	chomp $pypy_cmd;
	system("$pypy_cmd $my_dir/pycdump-scan/pycdump-scan.py --dump-ptr-vector $corefile >/dev/null") == 0 or
	      die "Cannot compute .vecbin from $corefile (pycdump-scan exited $?)";
}
open my $fh, '<', "$corefile.vecbin";
binmode $fh, ':raw';
$/ = undef;
my $mem_map = <$fh>;
#say length($mem_map);

my $map_to_map = $MEM_TO_MAP / 64;
my $mem_map_len = length($mem_map) / $map_to_map;
my @mem_map = map $_ ne '0' x $map_to_map ? '1' : '0',
                  unpack "a$map_to_map" x $mem_map_len, unpack 'b*', $mem_map;
$mem_map = join '', @mem_map;
#say $mem_map;

my @skips = ($mem_map =~ m/0+/g);
#say scalar @skips;
my $skip = 0;
map { $skip += length } @skips;
my $skip_total_b = $skip * $MEM_TO_MAP;
my $mem_total_b = $mem_map_len * $MEM_TO_MAP;
my $sweep_total_b = $mem_total_b - $skip_total_b;
say $mem_total_b, ' ', $sweep_total_b;
