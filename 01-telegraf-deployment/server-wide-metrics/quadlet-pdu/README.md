<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# Installation logbook:

To build the container image:

```bash
./build-and-push-image.sh
```

Choose the server where to deploy the container, only one node is needed since this container is not collectiong node metrics.

```bash
export NODE_NAME_SSH_ALIAS=<node_where_the_container_is_deployed>
```

I have sshed into the node and created a directory for the container:

```bash
ssh $NODE_NAME_SSH_ALIAS

mkdir -p /root/isac/pdu-quadlet
# ensure that the systemd/container dir exists
mkdir -p /etc/containers/systemd
```

Then I copied the [.ssh/id_ed25519.pub](./.ssh/id_ed25519.pub) into the `mon01` node's `~/.ssh/authorized_keys` file, so that the container can ssh into the node to collect the PDU metrics.


Then I copeid the [.ssh] folder into the node, so that the container can use the private key mounted as a volume
