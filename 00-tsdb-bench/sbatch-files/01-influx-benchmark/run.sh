#!/bin/bash
#SBATCH -A lade
#SBATCH -p THIN
#SBATCH --nodes=1
#SBATCH --mem=32G
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=144:00:00
#SBATCH --job-name=bnchk-tsbs
#SBATCH --get-user-env
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

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
NWORKERS=8
BATCHSIZE=1000
LIMIT=0

# -- Directories vars:
ROOT_DIR=$(git rev-parse --show-toplevel)
KUBE_CONFIG_FILE=${ROOT_DIR}/kube_setup/kube_config.yaml
HELM_DIR=${ROOT_DIR}/kube_setup/01-influxv2
RESULT_DIR=${ROOT_DIR}/newresults/influx
QUERY_FILE=${RESULT_DIR}/queriesinflux.gz

# ------------ Main script ------------

# ensure that tsbs_generate_data is available
if ! command -v tsbs_load_influx &> /dev/null
then
    echo "tsbs_load_influx could not be found. Please load the appropriate module or install it."
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

mkdir -p $RESULT_DIR

# define a function to load data
run_load_test() {
    tsbs_load_influx \
      --urls="$URL" \
      --do-load=true \
      --db-name="$BUCKET" \
      --do-create-db=false  \
      --file="$DATAFILE" \
      --workers="$NWORKERS" \
      --batch-size="$BATCHSIZE" \
      --limit="$LIMIT" \
      --hash-workers=true \
      --organization="$ORG" \
      --auth-token="$INFLUX_TOKEN"
}


generate_query_file() {
    tsbs_generate_queries \
      --format=influx \
      --use-case=devops \
      --scale=1000000 \
      --file=${RESULT_DIR}/queriesinflux.gz \
      --seed=123 \
      --debug=0 \
      --db-name=$BUCKET \
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
      export LOAD_OUTPUT_FILE="${RESULT_DIR}/influx_load_ram${RAM}_cores${CORES}_iter${i}.log"
      export OUTPUT_FILE="${RESULT_DIR}/influx_query_ram${RAM}_cores${CORES}_iter${i}.log"
      export HDR_FILE="${RESULT_DIR}/hdr_latencies_ram${RAM}_cores${CORES}_iter${i}.json"
      export RES_FILE="${RESULT_DIR}/results_ram${RAM}_cores${CORES}_iter${i}.json"
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
      helm  install influxv2chart influxdata/influxdb2 -f values.yaml --wait
      echo "Done; starting load test..."
      
      echo "---- waiting some time to get ready -----"
      sleep 10
      echo "-- done --"
      # run_load_test 2>&1 | tee $OUTPUT_FILE
      run_load_test > $LOAD_OUTPUT_FILE

      # Query benchmark is not a function to save all the files separately
      echo "Starting query benchmark..."
      tsbs_run_queries_influx \
        --urls="${URL}" \
        --burn-in=5000 \
        --chunk-response-size=0 \
        --debug=0 \
        --db-name=$BUCKET \
        --file=$QUERY_FILE \
        --hdr-latencies=$HDR_FILE \
        --max-queries=100000 \
        --max-rps=100000 \
        --results-file=$RES_FILE \
        --workers=$NWORKERS \
        --auth-token=$INFLUXDB_TOKEN > $OUTPUT_FILE
        # --auth-token=$INFLUXDB_TOKEN 2>&1 | tee $OUTPUT_FILE


      echo "Cleaning up: uninstalling InfluxDB..."
      helm uninstall influxv2chart
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

