# BSD 3-Clause License
# 
# Copyright (c) 2017, Tzung-Bi Shih
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

from collections import namedtuple
from struct import Struct
import mmap

"""
struct mach_header {
        uint32_t        magic;
        cpu_type_t      cputype;
        cpu_subtype_t   cpusubtype;
        uint32_t        filetype;
        uint32_t        ncmds;
        uint32_t        sizeofcmds;
        uint32_t        flags;
};

#define MH_MAGIC        0xfeedface
#define MH_CIGAM        0xcefaedfe
"""
mach_header = namedtuple('mach_header', 'magic cputype cpusubtype filetype ncmds sizeofcmds flags')
mach_header_struct = Struct('IiiIIII')
mh_magic = 0xfeedface
mh_cigam = 0xcefaedfe

"""
struct mach_header_64 {
        uint32_t        magic;
        cpu_type_t      cputype;
        cpu_subtype_t   cpusubtype;
        uint32_t        filetype;
        uint32_t        ncmds;
        uint32_t        sizeofcmds;
        uint32_t        flags;
        uint32_t        reserved;
};

#define MH_MAGIC_64 0xfeedfacf
#define MH_CIGAM_64 0xcffaedfe
"""
mach_header_64 = namedtuple('mach_header_64', 'magic cputype cpusubtype filetype ncmds sizeofcmds flags reserved')
mach_header_64_struct = Struct('IiiIIIII')
mh_magic_64 = 0xfeedfacf
mh_cigam_64 = 0xcffaedfe

"""
struct load_command {
        uint32_t cmd;
        uint32_t cmdsize;
};

#define LC_SEGMENT      0x1
#define LC_SEGMENT_64   0x19
"""
load_command = namedtuple('load_command', 'cmd cmdsize')
load_command_struct = Struct('II')
LC_SEGMENT = 0x1
LC_SEGMENT_64 = 0x19

"""
struct segment_command {
        uint32_t        cmd;
        uint32_t        cmdsize;
        char            segname[16];
        uint32_t        vmaddr;
        uint32_t        vmsize;
        uint32_t        fileoff;
        uint32_t        filesize;
        vm_prot_t       maxprot;
        vm_prot_t       initprot;
        uint32_t        nsects;
        uint32_t        flags;
};
"""
segment_command = namedtuple('segment_command', 'cmd cmdsize segname vmaddr vmsize fileoff filesize maxprot initprot nsects flags')
segment_command_struct = Struct('II16sIIIIiiII')

"""
struct segment_command_64 {
        uint32_t        cmd;
        uint32_t        cmdsize;
        char            segname[16];
        uint64_t        vmaddr;
        uint64_t        vmsize;
        uint64_t        fileoff;
        uint64_t        filesize;
        vm_prot_t       maxprot;
        vm_prot_t       initprot;
        uint32_t        nsects;
        uint32_t        flags;
};
"""
segment_command_64 = namedtuple('segment_command_64', 'cmd cmdsize segname vmaddr vmsize fileoff filesize maxprot initprot nsects flags')
segment_command_64_struct = Struct('II16sQQQQiiII')

"""
struct section {
        char            sectname[16];
        char            segname[16];
        uint32_t        addr;
        uint32_t        size;
        uint32_t        offset;
        uint32_t        align;
        uint32_t        reloff;
        uint32_t        nreloc;
        uint32_t        flags;
        uint32_t        reserved1;
        uint32_t        reserved2;
};
"""
section = namedtuple('section', 'sectname segname addr size offset align reloff nreloc flags reserved1 reserved2')
section_struct = Struct('16s16sIIIIIIIII')

"""
struct section_64 {
        char            sectname[16];
        char            segname[16];
        uint64_t        addr;
        uint64_t        size;
        uint32_t        offset;
        uint32_t        align;
        uint32_t        reloff;
        uint32_t        nreloc;
        uint32_t        flags;
        uint32_t        reserved1;
        uint32_t        reserved2;
        uint32_t        reserved3;
};
"""
section_64 = namedtuple('section_64', 'sectname segname addr size offset align reloff nreloc flags reserved1 reserved2 reserved3')
section_64_struct = Struct('16s16sQQIIIIIIII')


class MachO(object):
    def __init__(self, filename):
        self._filename = filename
        self._rf = None
        self._mm = None

    def __enter__(self):
        self._rf = open(self._filename, 'rb')
        self._mm = mmap.mmap(self._rf.fileno(), 0, mmap.MAP_PRIVATE, mmap.PROT_READ)
        return self

    def __exit__(self, exc_type, exc_value, exc_traceback):
        if exc_type is not None:
            pass
        self._mm.close()
        self._rf.close()

    def _get_header(self):
        """return a 3-tuple (begin_pos, end_pos, header)."""
        header = mach_header._make(mach_header_struct.unpack(self._mm[:mach_header_struct.size]))
        if header.magic == mh_magic_64 or header.magic == mh_cigam_64:
            return (0, mach_header_64_struct.size, mach_header_64._make(mach_header_64_struct.unpack(self._mm[:mach_header_64_struct.size])))
        else:
            return (0, mach_header_struct.size, header)

    def get_header(self):
        return self._get_header()[2]

    def _get_load_commands(self):
        """return a 3-tuple (begin_pos, end_pos, load_command)."""
        _, cur_pos, header = self._get_header()
        for i in range(header.ncmds):
            lc = load_command._make(load_command_struct.unpack(self._mm[cur_pos : cur_pos + load_command_struct.size]))
            yield (cur_pos, cur_pos + load_command_struct.size, lc)
            cur_pos += lc.cmdsize

    def get_load_commands(self):
        for _, _, lc in self._get_load_commands():
            yield lc

    def _get_segments(self):
        """return a 3-tuple (begin_pos, end_pos, segment)."""
        for pos, _, lc in self._get_load_commands():
            if lc.cmd == LC_SEGMENT_64:
                seg = segment_command_64._make(segment_command_64_struct.unpack(self._mm[pos : pos + segment_command_64_struct.size]))
                yield (pos, pos + segment_command_64_struct.size, seg)
            elif lc.cmd == LC_SEGMENT:
                seg = segment_command._make(segment_command_struct.unpack(self._mm[pos : pos + segment_command_struct.size]))
                yield (pos, pos + segment_command_struct.size, seg)

    def get_segments(self):
        for _, _, seg in self._get_segments():
            yield seg

    def _get_sections(self):
        """return a 3-tuple (begin_pos, end_pos, section)."""
        for pos, sect_pos, seg in self._get_segments():
            for i in range(seg.nsects):
                """NOTE: move the branch to outter loop will be better for performance consideration, but it will duplicate some code."""
                """NOTE: in the case, I don't care about the performance."""
                if seg.cmd == LC_SEGMENT_64:
                    sect = section_64._make(section_64_struct.unpack(self._mm[sect_pos : sect_pos + section_64_struct.size]))
                    yield (sect_pos, sect_pos + section_64_struct.size, sect)
                    sect_pos += section_64_struct.size
                else:
                    sect = section._make(section_struct.unpack(self._mm[sect_pos : sect_pos + section_struct.size]))
                    yield (sect_pos, sect_pos + section_struct.size, sect)
                    sect_pos += section_struct.size

    def get_sections(self):
        for _, _, sect in self._get_sections():
            yield sect

    def _get_data(self, offset, length):
        return self._mm[offset : offset + length]

    def get_section_data(self, segname, sectname):
        for sect in self.get_sections():
            if sect.segname.rstrip('\x00') == segname and sect.sectname.rstrip('\x00') == sectname:
                return self._get_data(sect.offset, sect.size).rstrip('\x00')
        return None
