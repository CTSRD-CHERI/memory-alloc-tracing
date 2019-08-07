#!/usr/bin/env python3
# Copyright (c) 2019 Lucian Paul-Trifu
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

import argparse
import os
import sys
from sortedcontainers import SortedDict
from struct import Struct

from macho_parser import MachO


"""
#define VM_PROT_READ	((vm_prot_t) 0x01)	/* read permission */
#define VM_PROT_WRITE	((vm_prot_t) 0x02)	/* write permission */
#define VM_PROT_EXECUTE	((vm_prot_t) 0x04)	/* execute permission */
"""
VM_PROT_READ    = 0x01
VM_PROT_WRITE   = 0x02
VM_PROT_EXECUTE = 0x04


def bool_ptr_map_of_coredump(cdump):
    struct_uint64 = Struct('=Q')

    ptr_map = []
    with MachO(args.coredump) as cdump:
        va_ranges = SortedDict((s.vmaddr, s.vmaddr + s.vmsize) for s in cdump.get_segments())

        for seg in (s for s in cdump.get_segments() if not s.initprot & VM_PROT_EXECUTE):
            # Ensure 8-byte alignment of the segment's vmaddr and vmsize
            vmaddr_8byte_aligned_up = (seg.vmaddr + 0x7) & ~0x7
            vmaddr_delta = vmaddr_8byte_aligned_up - seg.vmaddr
            vmsize_8byte_aligned_down = (seg.vmsize - vmaddr_delta) & ~0x7
            vmsize_delta = vmsize_8byte_aligned_down - seg.vmsize
            # Get 8-byte aligned segment data
            seg_data = cdump._get_data(seg.fileoff + vmaddr_delta, seg.filesize + vmsize_delta)
            seg_data_bytes = len(seg_data)

            for i, (uint64,) in enumerate(struct_uint64.iter_unpack(seg_data)):
                is_ptr = va_range_set_contains(va_ranges, uint64)
                ptr_map.append(is_ptr)

    return ptr_map, 8

def va_range_set_contains(va_ranges, point):
    va_range_base = va_ranges.iloc[va_ranges.bisect_right(point) - 1]
    va_range_end = va_ranges[va_range_base]
    return va_range_base <= point < va_range_end


my_dir = os.path.dirname(os.path.realpath(__file__))

parser = argparse.ArgumentParser(description='scans an ELF or MachO coredump file and '
                    'outputs a map of pointers to a file')
parser.add_argument('coredump', type=str, metavar='COREDUMP',
                    help="COREDUMP Mach-O file to scan.  The map of pointers "
                    "will be output to COREDUMP.vecbin in the current dir.")
args = parser.parse_args()

# Redirect execution to pycdump-scan.py if the host OS uses ELF coredumps
if os.uname().sysname.lower() != 'darwin':
    os.execl(sys.executable, sys.executable,
             my_dir+'/pycdump-scan/pycdump-scan.py', '--dump-ptr-vector', args.coredump)

ptr_map, ptr_size = bool_ptr_map_of_coredump(args.coredump)

# Turn the pointer map into a bit-vector and write it to a .vecbin
# file format (c) 2018 Hongyan Xia
with open(os.path.basename(args.coredump) + '.vecbin', 'wb') as vecbin:
    byte = 0
    byte_count = 0
    for i, is_ptr in enumerate(ptr_map):
        byte |= int(is_ptr) << (i % 8)
        if i % 8 == 7:
            vecbin.write(bytes((byte,)))
            byte = 0
            byte_count += 1
    assert byte_count == len(ptr_map) // 8, (byte_count, len(ptr_map), ptr_size)
