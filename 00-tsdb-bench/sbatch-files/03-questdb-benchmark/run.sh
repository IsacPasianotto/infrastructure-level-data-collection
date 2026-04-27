#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

#SBATCH -A lade
#SBATCH -p THIN
#SBATCH --nodes=1
#SBATCH --mem=32G
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=114:00:00
#SBATCH --job-name=tsdb-quest
#SBATCH --get-user-env
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --exclude=fat001,fat002

# -- Standard job preamble for debugging --
echo "---------------------------------------------"
echo "SLURM job ID:        $SLURM_JOB_ID"
echo "SLURM job node list: $SLURM_JOB_NODELIST"
echo "hostname:            $(hostname)"
echo "DATE:                $(date)"
echo "---------------------------------------------"

# -- Variables declaration --
source .env
BUCKET="default"
DATAFILE="${SCRATCH_DIR}/dataquestsmall.gz"
NWORKERS=8
BATCHSIZE=1000
LIMIT=0

# -- Directories vars:
ROOT_DIR=$(git rev-parse --show-toplevel)
KUBE_CONFIG_FILE=${ROOT_DIR}/00-tsdb-bench/kube_setup/kube_config.yaml
HELM_DIR=${ROOT_DIR}/00-tsdb-bench/kube_setup/03-questdb
RESULT_DIR=${ROOT_DIR}/00-tsdb-bench/newresults/questdb
QUERY_FILE=${RESULT_DIR}/queriesquestdb.gz

# ------------ Main script ------------

# ensure that tsbs_generate_data is available
if ! command -v tsbs_load_questdb &> /dev/null
then
    echo "tsbs_load_questdb could not be found. Please load the appropriate module or install it."
    exit
fi
# ensure that the kubeconfig file exists
if [ ! -f "$KUBE_CONFIG_FILE" ]; then
    echo "Kubeconfig file not found at $KUBE_CONFIG_FILE"
    exit 1
fi

echo "Using kubeconfig file at $KUBE_CONFIG_FILE"
export KUBECONFIG=$KUBE_CONFIG_FILE
if ! kubectl version --client &> /dev/null; then
    echo "Invalid kubeconfig file or unable to connect to the cluster."
    exit 1
fi
helm repo add questdb https://helm.questdb.io/
helm repo update


mkdir -p $RESULT_DIR

# define a function to load data
run_load_test() {

echo "Waiting for QuestDB to become ready..."
for i in {1..30}; do
    if curl -sSf "${URL}/exec?query=SHOW+TABLES" > /dev/null; then
        echo "QuestDB is ready!"
        break
    fi
    echo "Attempt $i: QuestDB not ready yet, sleeping 10s..."
    sleep 10
done


  tsbs_load_questdb \
    --url=$URL \
    --seed=42 \
    --workers=$NWORKERS \
    --limit=0 \
    --do-load=true \
    --batch-size=$BATCHSIZE \
    --hash-workers=true \
    --ilp-bind-to=$ILPBINDTO \
    --file=$DATAFILE
}


generate_query_file() {
    tsbs_generate_queries \
      --format=questdb \
      --use-case=devops \
      --scale=1000000 \
      --file=${RESULT_DIR}/queriesquestdb.gz \
      --seed=123 \
      --debug=0 \
      --queries=1000000 \
      --query-type=single-groupby-5-1-12
}
# Generate the query data
generate_query_file


# -- Main logic --

pushd $HELM_DIR || { echo "Helm directory not found!"; exit 1; }
for r in 8 16 32 64
do
  for c in 4 8 12 16 18
  do
    for i in {1..10}
    do
      source .env
      export CORES=$c
      export RAM=${r}Gi
      export LOAD_OUTPUT_FILE="${RESULT_DIR}/questdb_load_ram${RAM}_cores${CORES}_iter${i}.log"
      export OUTPUT_FILE="${RESULT_DIR}/questdb_query_ram${RAM}_cores${CORES}_iter${i}.log"
      export HDR_FILE="${RESULT_DIR}/questdb_latencies_ram${RAM}_cores${CORES}_iter${i}.json"
      export RES_FILE="${RESULT_DIR}/questdb_ram${RAM}_cores${CORES}_iter${i}.json"
      echo "---------------------------------------------"
      echo " Time: $(date)"
      echo " Ram: $RAM"
      echo " Cores: $CORES"
      echo " Iteration: $i"
      echo " Load output file: $LOAD_OUTPUT_FILE"
      echo " Query output file: $OUTPUT_FILE"
      echo " HDR latencies file: $HDR_FILE"
      echo " Query Results file: $RES_FILE"
      echo "---------------------------------------------"
      envsubst < values_tmpl.yaml > values.yaml
      helm install questdb questdb/questdb -f values.yaml --wait
      echo "Done; starting load test..."
      run_load_test > $LOAD_OUTPUT_FILE

      # Query benchmark is not a function to save all the files separately
      echo "Starting query benchmark..."
      tsbs_run_queries_questdb \
        --urls="${URL}" \
        --burn-in=5000 \
        --debug=0 \
        --file=$QUERY_FILE \
        --hdr-latencies=$HDR_FILE \
        --max-queries=100000 \
        --max-rps=100000 \
        --results-file=$RES_FILE \
        --workers=$NWORKERS  > $OUTPUT_FILE


      echo "Cleaning up: uninstalling QuestDB..."
      helm uninstall questdb
      # Remove PVCs to ensure a clean state for the next iteration
      kubectl delete pvc --all
      echo "Cleanup done."


    done
  done
done

popd || { echo "Failed to return from Helm directory!"; exit 1; }

# -- Standard end --
echo "---------------------------------------------"
echo "Done!"
echo "DATE: $(date)"
echo "It took $SECONDS seconds"
echo "---------------------------------------------"

