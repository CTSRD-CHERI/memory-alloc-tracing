#!/usr/bin/env perl
# Copyright (c) 2018 Lucian Paul-Trifu
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

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
my $vecbin_file = "$corefile.vecbin";
$vecbin_file = basename("$corefile.vecbin") if ! -e $vecbin_file;
if (!-e $vecbin_file) {
	my $pypy_cmd = `which pypy3`;
	chomp $pypy_cmd;
	system("$pypy_cmd $my_dir/cdump-map-pointers.py $corefile >/dev/null") == 0 or
	      die "Cannot compute .vecbin from $corefile (cdump-map-pointers exited $?)";
}
open my $fh, '<', $vecbin_file;
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
