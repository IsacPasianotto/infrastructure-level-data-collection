#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

# ---- color definitions  -----
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


# --------- Function definitions ---------
log() {
    printf "${GREEN}[%(%F %T)T]${NC} %s\n" -1 "$*"
}

warn() {
    printf "${YELLOW}[%(%F %T)T] WARNING:${NC} %s\n" -1 "$*" >&2
}

die() {
    printf "${RED}[%(%F %T)T] ERROR:${NC} %s\n" -1 "$*" >&2
    exit 1
}

section() {
    printf "\n${BLUE}============================================================${NC}\n"
    printf "${BLUE}%s${NC}\n" "$*"
    printf "${BLUE}============================================================${NC}\n"
}

subsection() {
    printf "\n${BLUE}-------------------- %s --------------------${NC}\n" "$*"
}

separator() {
    printf "\n${BLUE}------------------------------------------------------------${NC}\n"
}