#!/usr/bin/env bash

samples_file=$1
trace_file=$2

cpu_ts_fieldnum_sf=`grep -m1 cpu-time-ns $samples_file | tr '\t' '\n' |
                    grep -n cpu-time-ns | grep -E -o '^[0-9]+'`
cpu_ts_fieldnum_tf=`grep -m1 cpu-time-ns $trace_file | tr '\t' '\n' |
                    grep -n cpu-time-ns | grep -E -o '^[0-9]+'`

# Merge the two sources, copying cpu-timestamps from the
# trace records to the address-space samples records (they don't have a
# valid CPU timestamp)
sort -m -k 2n ${trace_file} ${samples_file} | awk "
                                    BEGIN{ FS=\"\t\"; OFS=\"\t\"; cpu_ts_last=0 }
                                    {
                                      if (\$1 == \"aspace-sample\" && !(\$0 ~ /^#|^@/))
                                         \$$cpu_ts_fieldnum_sf = cpu_ts_last;
                                      if (\$1 == \"call-trace\" && !(\$0 ~ /^#|^@/))
                                         cpu_ts_last = \$$cpu_ts_fieldnum_tf;
                                      print \$0;
                                    }"
