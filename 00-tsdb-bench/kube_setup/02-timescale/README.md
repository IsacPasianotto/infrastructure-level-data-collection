# Timesclae installation


1. populate the `.env` file:

```
export CORES=16
export RAM=64Gi


export PG_USERNAME=<your_base64_encoded_username>
export PG_PASSWORD=<your_base64_encoded_password>

export METALLB_POOL=<your_metallb_pool>
export METALLB_IP=<your_external_ip>
```

3. Source the `.env` file and generate the needed files

```bash
source .env
envsubst < 01-sec-tmpl.yaml > 01-sec.yaml
envsubst < 02-cluster-tmpl.yaml > 02-cluster.yaml
envsubst < 03-svc-tmpl.yaml > 03-svc.yaml
```


4. Apply the manifest:

```bash
kubectl apply -f 01-sec.yaml
kubectl apply -f 02-cluster.yaml
kubectl apply -f 03-svc.yaml
```
