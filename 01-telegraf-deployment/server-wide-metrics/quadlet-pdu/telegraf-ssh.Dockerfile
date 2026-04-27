# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: CC-BY-4.0

FROM telegraf:latest

# switch to root to install extra packages
USER root

RUN apt update && apt install -y openssh-client && rm -rf /var/lib/apt/lists/*

# switch back to non-root for running telegraf
USER telegraf