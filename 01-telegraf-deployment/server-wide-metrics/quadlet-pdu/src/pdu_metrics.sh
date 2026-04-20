#!/bin/bash

SCRIPT="/root/isac/metrics.sh"
CSV_FILE="/root/isac/connection.csv"

RAW=$(ssh mon01 ${SCRIPT} ${CSV_FILE})

# debug
# printf "%s\n" "$RAW"

# Convert CSV -> Influx Line Protocol
# CSV columns:
# pdu-name,power-outlet-num,connected-device,connected-port,value
echo "$RAW" | awk -F',' '
NR==1 { next }  # skip header

function esc_tag(s) {
  gsub(/\\/,"\\\\",s)   # backslash
  gsub(/ /,"\\ ",s)     # space
  gsub(/,/,"\\,",s)     # comma
  gsub(/=/,"\\=",s)     # equals
  return s
}

{
  pdu   = esc_tag($1)
  outlet= esc_tag($2)
  dev   = esc_tag($3)
  port  = esc_tag($4)
  val   = $5

  # Trim CR (if any)
  gsub(/\r$/, "", val)

  if (val == "" || val == "null") next

  # If value is integer, append i for Influx integer type
  if (val ~ /^-?[0-9]+$/) {
    printf "pdu_power,pdu=%s,outlet_num=%s,connected_device=%s,port=%s value_W=%si\n", pdu, outlet, dev, port, val
  } else {
    # otherwise float
    printf "pdu_power,pdu=%s,outlet_num=%s,connected_device=%s,port=%s value_W=%s\n", pdu, outlet, dev, port, val
  }
}'

# NOTE: 
#
# for some reasons, only those PDUS, still be missing values always:
#   which is the reason why I have put that if val == "" next
#
#
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=1,connected_device=mon01,port=pw value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=2,connected_device=pfsense02,port=pw-dx value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=3,connected_device=pfsense01,port=pw-dx value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=31,connected_device=dgx001,port=pw1 value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=32,connected_device=dgx001,port=pw2 value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=33,connected_device=dgx001,port=pw3 value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=34,connected_device=dgx002,port=pw1 value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=35,connected_device=dgx002,port=pw2 value_W=
# pdu_power,pdu=16-PDU-DX-Array2-Rack04,outlet_num=36,connected_device=dgx002,port=pw3 value_W=
