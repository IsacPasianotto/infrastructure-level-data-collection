<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# QuestDB installation

1. Add the helm repository

```bash

helm repo add questdb https://helm.questdb.io/
helm repo update
```

2. Populate the `.env` file:

```
export CORES=16
export RAM=64Gi


export KUBE_NOE_HOSTNAME=<kube_host_where_to_place_the_pod>
export METALLB_POOL=<your_metallb_pool>
export INGRESS_CLASS=<your_ingress_class>
export INGRESS_SECRET_NAME=<your_tls_secret_name>
export INGRESS_HOST=<your_service_hostname>
export INGRESS_CLUSTER_ISSUER=<your_cluster_issuer_name>
```

3. Generate the values.yaml file and apply the manifest:

```bash
source .env
envsubst < values_tmpl.yaml > values.yaml

helm install questdb questdb/questdb -f values.yaml
```


