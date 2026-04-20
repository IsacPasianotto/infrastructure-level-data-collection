#!/bin/bash

# escape SQL string: replace ' with '' and wrap in single quotes
function sql_escape() {
  local s="$1"
  s="${s//\'/\'\'}"
  printf "%s" "$s"
}

function  exec_query() {
    local query="$1"
    local host="$2"
    curl -sS -G \
      --data-urlencode "query=$query" \
      "$host/exec"
    # curl return has no newline
    echo ""
}

function run_experiment_help() {
cat <<EOF
Usage: run_experiment [OPTIONS]

Required parameters:
  --slurm-job-id ID
  --slurm-nodes NODES
  --config-dir DIR
  --output-dir DIR
  --n-iter N
  --ntasks N
  --backend NAME
  --scenario NAME

Example:
  run_experiment \
    --slurm-job-id 12345 \
    --slurm-nodes node01 \
    --config-dir ./configs \
    --output-dir ./results \
    --n-iter 1 \
    --ntasks 16 \
    --backend posix \
    --scenario seq_write
EOF
}

function run_experiment() {

    # --- parameters ---
    local slurm_job_id=""
    local slurm_nodes=""
    local config_dir=""
    local output_dir=""
    local n_iter=""
    local ntasks=""
    local backend=""
    local scenario=""

    # --- parse arguments ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --slurm-job-id)
                slurm_job_id="$2"
                shift 2
                ;;
            --slurm-nodes)
                slurm_nodes="$2"
                shift 2
                ;;
            --config-dir)
                config_dir="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --n-iter)
                n_iter="$2"
                shift 2
                ;;
            --ntasks)
                ntasks="$2"
                shift 2
                ;;
            --backend)
                backend="$2"
                shift 2
                ;;
            --scenario)
                scenario="$2"
                shift 2
                ;;
            --help)
                run_experiment_help
                return 0
                ;;
            *)
                echo "Unknown parameter: $1"
                run_experiment_help
                return 1
                ;;
        esac
    done

    # --- check required parameters ---
    if [[ -z "$slurm_job_id" || \
          -z "$slurm_nodes" || \
          -z "$config_dir" || \
          -z "$output_dir" || \
          -z "$n_iter" || \
          -z "$ntasks" || \
          -z "$backend" || \
          -z "$scenario" ]]; then
        echo "Error: missing required parameters"
        echo ""
        run_experiment_help
        return 1
    fi

    # --- constants ---
    local db_url="https://timeseriesdb.dev.rd.areasciencepark.it"
    config_file="${config_dir}/${scenario}.ini"
    summary_file="${output_dir}/${scenario}_${backend}_summary.txt"

    [[ -f ${config_file} ]] || die "Config file ${config_file} not found for scenario ${scenario}"

    argstopass=" -f ${config_file} -a ${backend} -O summaryFile=${summary_file}_${n_iter} -N ${ntasks}"
    QUERY="INSERT INTO experiments VALUES (now(), rnd_uuid4(), '$slurm_job_id', '$slurm_nodes', 'START', 'IOR-backend=${backend}-scenario=${scenario}_${n_iter}');"

    subsection "Running: backend=${backend}, scenario=${scenario}, n_iter=${n_iter}"
    log "Starting at timestamp: $(date)"
    exec_query "$QUERY" "$db_url"

    mpirun -np ${ntasks} ior ${argstopass} >> run_log.log 2>&1

    QUERY="INSERT INTO experiments VALUES (now(), rnd_uuid4(), '$slurm_job_id', '$slurm_nodes', 'END', 'IOR-backend=${backend}-scenario=${scenario}_${n_iter}');"
    exec_query "$QUERY" "$db_url"
    log "Finished at timestamp: $(date)"
    separator
}
