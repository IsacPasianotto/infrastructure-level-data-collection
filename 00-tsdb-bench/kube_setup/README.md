<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# Kubernetes setup

First of all, create a `.env-kube` file with the follwoing content:

```
export KUBE_SERVER_IP=<your_cluster_ip_there>
export KUBE_USER=<your_kubernetes_user_there>
export KUBE_NS=<your_namespace_there>
export KUBE_CA_DATA=<your_cluster_certification_authority_there>
export KUBE_CERT=<your_base64_encoded_key_there>
export KUBE_KEY=<your_base64_encoded_key_there>
```

then generate and set the Kubernetes configuration with:

```bash
source .env-kube
envsubst < kube_config.tmpl > kube_config.yaml
export KUBECONFIG=$(pwd)/kube_config.yaml
```

## Databases Setup

For each of the databased used: `QuestDB`, `TimescaleDB`, `InfluxDB`, there is the corresponding directory with the deployment configuration and instructions.
Since all of the databases are deployed and then immediately destroyed after the benchmark, a fac simile of the env vars with dummy vales is provided in the .env file of each folder. 
These values are not meant to be used in any production environment. 