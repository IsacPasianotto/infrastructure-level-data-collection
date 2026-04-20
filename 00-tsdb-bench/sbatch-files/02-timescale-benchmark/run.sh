#!/bin/bash
#SBATCH -A lade
#SBATCH -p THIN
#SBATCH --nodes=1
#SBATCH --mem=32G
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=144:00:00
#SBATCH --job-name=tsdb-timescale
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

# needed only because kubectl cnpg path was declared there!
source $HOME/.bashrc 

# -- Variables declaration --
source .env
DATAFILE="${SCRATCH_DIR}/datatimescalesmall.gz"
NWORKERS=8
BATCHSIZE=1000
LIMIT=0

# -- Directories vars:
ROOT_DIR=$(git rev-parse --show-toplevel)
KUBE_CONFIG_FILE=${ROOT_DIR}/00-tsdb-bench/kube_setup/kube_config.yaml
MANIFEST_DIR=${ROOT_DIR}/00-tsdb-bench/kube_setup/02-timescale
RESULT_DIR=${ROOT_DIR}/00-tsdb-bench/newresults/timescale
QUERY_FILE=${RESULT_DIR}/queriestimescale.gz

# ------------ Main script ------------

# ensure that tsbs_generate_data is available
if ! command -v tsbs_load_timescaledb &> /dev/null
then
    echo "tsbs_load_timescaledb could not be found. Please load the appropriate module or install it."
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

# ensure that kubectl cnpg is available
if ! command -v kubectl cnpg version &> /dev/null
then
    echo "kubectl cnpg could not be found. Please install the kubectl cnpg plugin."
    exit
fi

mkdir -p $RESULT_DIR

# define a function to load data
run_load_test() {
    # Ensure the database is ready because --wait does not work
    # properly with cnpg operator
    while true; do
      status=$(kubectl cnpg status demo-db | grep "Status:" | sed 's/.*Status:[[:space:]]*//' | tr -d '\r' | sed 's/\x1b\[[0-9;]*m//g' | xargs)
      echo "Current status: $status"
      # See if the status is: "Cluster in healthy state"

      if [[ "$status" == "Cluster in healthy state" ]]; then
        echo "---- Database is ready! ----"
        break
      fi

      sleep 5
    done

    # Give to the PG_USER the permission to create databases
    export pgcontroller=$(kubectl cnpg status demo-db | grep "Primary instance" | awk '{print $3}')
    kubectl exec -it $pgcontroller -- psql -U postgres -d postgres -c "ALTER ROLE ${PG_USER} CREATEDB;"


  tsbs_load_timescaledb \
        --seed=42 \
	--host=${METALLB_IP} \
	--port=${PG_PORT} \
	--use-insert \
	--user=${PG_USER} \
	--pass=${PG_PASSWD} \
	--batch-size=${BATCHSIZE} \
	--create-metrics-table \
	--admin-db-name=${ADMIN_DB_NAME} \
	--db-name=${DB_NAME} \
	--do-create-db \
	--limit=0 \
	--postgres="sslmode=disable" \
	--workers=$NWORKERS \
	--use-hypertable=False \
	 --file=${DATAFILE}
}


generate_query_file() {
    tsbs_generate_queries \
      --format=timescaledb \
      --use-case=devops \
      --scale=1000000 \
      --file=${RESULT_DIR}/queriestimescaledb.gz \
      --seed=123 \
      --debug=0 \
      --queries=1000000 \
      --query-type=single-groupby-5-1-12
}
# Generate the query data
generate_query_file


# -- Main logic --

pushd $MANIFEST_DIR || { echo "Helm directory not found!"; exit 1; }
for r in 3 5 10 21
do
  for c in 2 3 4 5 6
  do
    for i in {1..10}
    do
      source .env
      export CORES=$c
      export RAM=${r}Gi

      # --- Derived values only for filenames ---
      case $r in
        3) r_name=8  ;;
        5) r_name=16 ;;
        10) r_name=32 ;;
        21) r_name=64 ;;
      esac

      case $c in
        2) c_name=4 ;;
        3) c_name=8 ;;
        4) c_name=12 ;;
        5) c_name=16 ;;
        6) c_name=18 ;;
      esac

      export LOAD_OUTPUT_FILE="${RESULT_DIR}/timescale_load_ram${r_name}_cores${c_name}_iter${i}.log"
      export OUTPUT_FILE="${RESULT_DIR}/timescale_query_ram${r_name}_cores${c_name}_iter${i}.log"
      export HDR_FILE="${RESULT_DIR}/timescale_latencies_ram${r_name}_cores${c_name}_iter${i}.json"
      export RES_FILE="${RESULT_DIR}/timescale_ram${r_name}_cores${c_name}_iter${i}.json"
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

      # Installation
      envsubst < 01-sec-tmpl.yaml > 01-sec.yaml
      envsubst < 02-cluster-tmpl.yaml > 02-cluster.yaml
      envsubst < 03-svc-tmpl.yaml > 03-svc.yaml
      kubectl apply -f 01-sec.yaml
      kubectl apply -f 02-cluster.yaml
      kubectl apply -f 03-svc.yaml

      echo "Done; starting load test..."
      run_load_test > $LOAD_OUTPUT_FILE

      # Install the timescaledb extension in the database
      pgcontroller=$(kubectl cnpg status demo-db | grep "Primary instance" | awk '{print $3}')
      kubectl exec -it $pgcontroller -- psql -U postgres -d ${DB_NAME} -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

      echo "Starting query benchmark..."
      tsbs_run_queries_timescaledb \
        --burn-in=5000 \
        --db-name=${DB_NAME} \
        --debug=0 \
        --file=${RESULT_DIR}/queriestimescaledb.gz \
        --hdr-latencies=${HDR_FILE} \
        --hosts=${METALLB_IP} \
        --max-queries=100000 \
        --max-rps=100000 \
        --user=${PG_USER} \
        --pass=${PG_PASSWD} \
        --port=${PG_PORT} \
        --postgres="host=${METALLB_IP} user=${PG_USER} sslmode=disable" \
        --print-responses=false \
        --results-file=${RES_FILE} \
        --workers=$NWORKERS  > $OUTPUT_FILE

      echo "Cleaning up: uninstalling TimescaleDB..."
      kubectl delete -f 03-svc.yaml
      kubectl delete -f 02-cluster.yaml
      kubectl delete -f 01-sec.yaml
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


