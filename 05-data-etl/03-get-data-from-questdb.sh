#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

QUESTDB_HOST="<INGRESS_HOST_IN_QUESTDB_DEPLOYMENT>"                 # <-- TODO: replace this
BASE_URL="https://${QUESTDB_HOST}/exp"

# --- Constants:
PRJ_ROOT_DIR=$(git rev-parse --show-toplevel)
DATA_DIR="$PRJ_ROOT_DIR/questdb-parquet-data"

# define the first and last day to download data for (FROM inclusive, TO exclusive)
DAY_FROM="2026-03-02"                                                # <-- TODO: replace this
DAY_TO="2026-03-29"                                                  # <-- TODO: replace this

ranges=()

current="$DAY_FROM"
while [[ "$current" < "$DAY_TO" ]]; do
  next=$(date -u -d "$current +1 day" +%F)
  ranges+=("$current $next")
  current="$next"
done


tables=(
 "pdu_power"
  "energy_meter"
  "cpu"
  "diskio"
  "infiniband"
  "ipmi_power"
  "ipmi_sensor"
  "net"
  "nvidia_smi"
  "turbostat"
  "mem"
)

# !! Important, the order must match the order of `tables` !!
columns_to_query=(
  "timestamp,pdu,port,outlet_num,connected_device,value_W"
  "timestamp,unit,value,description"
  "timestamp,core_id,host,physical_id,usage_iowait,usage_irq,usage_guest_nice,usage_user,usage_idle,usage_softirq,usage_steal,usage_system,usage_nice"
  "timestamp,host,name,weighted_io_time,merged_writes,reads,writes,read_bytes,write_bytes,read_time,write_time,iops_in_progress,merged_reads,io_time,io_util,io_await,io_svctm"
  "timestamp,host,device,port_rcv_data,port_rcv_packets,port_xmit_packets,multicast_xmit_packets,unicast_xmit_packets,unicast_rcv_packets,port_xmit_data,multicast_rcv_packets"
  "timestamp,host,psu_id,type,unit,value"l
  "timestamp,host,name,unit,value"
  "timestamp,host,interface,bytes_sent,bytes_recv,packets_sent,packets_recv"
  "timestamp,host,index,name,utilization_gpu,memory_total,memory_free,clocks_current_graphics,memory_used,clocks_current_sm,clocks_current_memory,utilization_memory,clocks_current_video,temperature_gpu,power_draw,memory_reserved"
  "timestamp,core,cpu,die,host,l3,node,package,x2apic,c1_plus,core_power_watt,c2,busy_percent,poll_minus,poll,c2_plus,package_power_watt,tsc_frequency_mhz,irq,smi,usec,average_frequency_mhz,busy_frequency_mhz,c1_minus,c2_minus,c1_percent,ipc,nmi,poll_percent,c2_percent,c1,c1e_minus,c6_plus,c1e_plus,core_temperature_celsius,core_throttle,c6_minus,cpu_percent_c6,ram_power_watt,package_temperature_celsius,package_percent_pc6,package_percent,ram_percent,uncore_frequency_mhz,c6_percent,package_percent_pc2,c6,c1e_percent,c1e,cpu_percent_c1,system_power_watt"
  "timestamp,host,committed_as,mapped,write_back,available,used_percent,huge_pages_free,slab,sunreclaim,swap_total,swap_cached,available_percent,high_free,huge_page_size,huge_pages_total,page_tables,dirty,low_total,vmalloc_chunk,used,free,sreclaimable,vmalloc_total,total,active,buffered,write_back_tmp,cached,commit_limit,high_total,inactive,low_free,shared,swap_free,vmalloc_used"
)

if [ "${#tables[@]}" -ne "${#columns_to_query[@]}" ]; then
  echo "Error: tables and columns_to_query must have the same length" >&2
  exit 1
fi

for i in "${!tables[@]}"; do
  table="${tables[$i]}"
  columns="${columns_to_query[$i]}"

  echo "------------------------------------------"
  echo "  Downloading data for table: $table"
  echo "------------------------------------------"

  mkdir -p "$DATA_DIR/$table"

  for r in "${ranges[@]}"; do
    start=$(awk '{print $1}' <<< "$r")
    end=$(awk '{print $2}' <<< "$r")
    out="$DATA_DIR/${table}/${table}_${start}_${end}.parquet"

    echo "Downloading $out ..."

    query="SELECT ${columns}
FROM ${table}
WHERE timestamp >= '${start}T00:00:00.000000Z'
AND timestamp < '${end}T00:00:00.000000Z';"


    curl --fail --silent --show-error -G \
      "$BASE_URL" \
      --data-urlencode "query=${query}" \
      --data-urlencode "fmt=parquet" \
      --output "$out"
  done
done