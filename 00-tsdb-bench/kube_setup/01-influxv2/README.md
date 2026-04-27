<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# InfluxDB v2 installation

1. Add the helm repository

```bash
helm repo add influxdata https://helm.influxdata.com/
helm repo update
```

2. Populate the `.env` file:

```
export CORES=16
export RAM=64Gi

export ORGANIZATION=influxdata
export BUCKET=default
export USER=<your_username>
export PASSWORD=<your_password>

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
helm  install influxv2chart influxdata/influxdb2 -f values.yaml
```

