#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

SVC_NAME="${SVC_NAME:-localhost}"
SVC_PORT="${SVC_PORT:-8089}"
METRICS_PATH="${METRICS_PATH:-/metrics}"

curl -s "http://${SVC_NAME}:${SVC_PORT}${METRICS_PATH}" | awk '
function esc_tag(s,    t) {
  t=s
  gsub(/\\/,"\\\\",t)
  gsub(/,/,"\\,",t)
  gsub(/ /,"\\ ",t)
  gsub(/=/,"\\=",t)
  return t
}

BEGIN { desc="" }

/^[[:space:]]*#/ {
  desc = $0
  sub(/^[[:space:]]*#[[:space:]]*/, "", desc)
  next
}

/^vcId_[0-9]+/ {
  line = $0

  # vcid: numero dopo vcId_
  if (match(line, /^vcId_[0-9]+/)) {
    vcid = substr(line, 6, RLENGTH-5)
  } else {
    next
  }

  # unit: se presente unit="..."
  unit = ""
  if (match(line, /unit="[^"]*"/)) {
    tmp = substr(line, RSTART, RLENGTH)
    sub(/^unit="/, "", tmp)
    sub(/"$/, "", tmp)
    unit = tmp
  }

  # valore: ultimo campo
  n = split(line, a, /[[:space:]]+/)
  val = a[n]

  # se unit è vuota, non includere il tag unit (tag vuoti non sono validi)
  if (unit == "") {
    printf("energy_meter,description=%s,vcID=%s value=%s\n",
           esc_tag(desc), esc_tag(vcid), val)
  } else {
    printf("energy_meter,description=%s,vcID=%s,unit=%s value=%s\n",
           esc_tag(desc), esc_tag(vcid), esc_tag(unit), val)
  }
}
'