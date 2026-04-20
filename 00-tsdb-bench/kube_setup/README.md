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
