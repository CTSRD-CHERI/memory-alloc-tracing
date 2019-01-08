#!/usr/bin/env bash

samples_file=$1
trace_file=$2

num_recs_sf=`head -n1 $samples_file | tr '\t' '\n' | wc -l | tr -d [:space:]`
num_recs_tf=`head -n1 $trace_file | tr '\t' '\n' | wc -l | tr -d [:space:]`

cpu_ts_fieldnum_sf=`head -n1 $samples_file | tr '\t' '\n' |
                    grep -n cpu-time-ns | grep -E -o '^[0-9]+'`
cpu_ts_fieldnum_tf=`head -n1 $trace_file | tr '\t' '\n' |
                    grep -n cpu-time-ns | grep -E -o '^[0-9]+'`

# Merge the two sources, copying cpu-timestamps from the
# trace records to the address-space samples records (they don't have a
# valid CPU timestamp)
sort -m -k 1n ${trace_file} ${samples_file} | awk "
                                    BEGIN{ FS=\"\t\"; OFS=\"\t\"; cpu_ts_last=0 }
                                    {
                                      if (NF == $num_recs_sf && !(\$0 ~ /^#/))
                                         \$$cpu_ts_fieldnum_sf = cpu_ts_last;
                                      if (NF == $num_recs_tf && !(\$0 ~ /^#/))
                                         cpu_ts_last = \$$cpu_ts_fieldnum_tf;
                                      print \$0;
                                    }"
