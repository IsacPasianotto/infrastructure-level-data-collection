#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

export PROJECT_DIR=$(git rev-parse --show-toplevel)
pushd $PROJECT_DIR > /dev/null || exit 1

echo "============ building the container ============ "

pushd ./container-image > /dev/null || exit 1

# clone the repo and appl the custom config
if [ ! -d "telegraf" ]; then
    git clone -b v1.37.0 https://github.com/influxdata/telegraf.git
fi

pushd telegraf > /dev/null || exit 1
# git apply amd.patch
#  ----- PATCH ----
# before:
#      case "package", "node", "die", "core", "cpu", "apic", "x2apic":
# after:
#      case "package", "node", "die", "core", "cpu", "apic", "x2apic", "l3":
#
sed -i '/"l3"/! s/"x2apic":/"x2apic", "l3":/' plugins/inputs/turbostat/turbostat.go
# before:
#     	case "v12":
# after:
#       case "v12", "v13":
sed -i '/"v13"/! s/"v12":/"v12", "v13":/' plugins/inputs/nvidia_smi/nvidia_smi.go



echo " ----- building the telegraf patched binaries ----- "
podman run --memory=8g --pids-limit=-1 --rm -v $(pwd):/usr/src/telegraf -w /usr/src/telegraf golang:1.25 make
echo " ----- done ----- "

# exit telegraf dir
popd > /dev/null || exit 1


podman build -t telegraf-monitoring .
podman tag telegraf-monitoring docker.io/${DOCKERHUB_USERNAME:-$(whoami)}/telegraf-monitoring:latest
podman login docker.io

# exit the container-image dir
popd > /dev/null || exit 1
echo "=========== container built successfully =========="
echo "=========== pushing container images to docker.io =========="
podman push docker.io/${DOCKERHUB_USERNAME:-$(whoami)}/telegraf-monitoring:latest

# return in the original dir
popd > /dev/null || exit 1
