# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: CC-BY-4.0

FROM fedora:43

# install the needed dependencies
RUN dnf install -y \
  iputils \
  net-snmp \
  procps-ng \
  lm_sensors \
  libcap \
  util-linux \
  wget \
  turbostat \
  freeipmi \
  hostname \
  sudo \
  && dnf clean all


RUN mkdir /etc/telegraf

RUN groupadd -r telegraf && \
  useradd -r -u 992 -g telegraf -d /etc/telegraf -s /bin/false telegraf


EXPOSE 8125/udp 8092/udp 8094

COPY telegraf/telegraf /usr/bin/telegraf
COPY entrypoint.sh /entrypoint.sh
RUN chmod o+x /entrypoint.sh

RUN echo "telegraf ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/telegraf \
    && chmod 0440 /etc/sudoers.d/telegraf


# USER telegraf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]
