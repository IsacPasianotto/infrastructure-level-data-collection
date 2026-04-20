#!/bin/bash
#SBATCH -A mgm
#SBATCH -p GENOA
#SBATCH --nodes=2
#SBATCH --mem=490G
#SBATCH --ntasks-per-node=64
#SBATCH --cpus-per-task=1
#SBATCH --time=48:00:00
#SBATCH --job-name=io-cephstress
#SBATCH --output=slurmout/slurm-%j.out
#SBATCH --error=slurmout/slurm-%j.err

set -euo pipefail

# ------- Environment variables --------
NTASKS="${SLURM_NTASKS:-64}"           # total number of tasks
NNODES="${SLURM_JOB_NUM_NODES:-1}"     # number of nodes allocated
PARTITION="${SLURM_JOB_PARTITION:-unknown}"
BACKENDS=("POSIX" "MPIIO")
N_ITER=10
SLEEP_DURATION=120  # 2 minutes

# -- repo dirs
ROOT_DIR="$(git rev-parse --show-toplevel)"
OUTPUT_DIR="${ROOT_DIR}/02-ior-bench/results/${PARTITION}/scratch"
CONFIG_DIR="${ROOT_DIR}/02-ior-bench/configs/scratch"

# -- scenarios to run (config files)
SCENARIOS=(
	write_seq_4k
	read_seq_4k
	write_seq_4m
	read_seq_4m
	write_rand_4k
	read_rand_4k
	writeread_rand_4k_shared
)

mkdir -p "${OUTPUT_DIR}"
cd "${ROOT_DIR}"
source "${ROOT_DIR}/utils/logging.sh"
source "${ROOT_DIR}/utils/run_exp.sh"

# -------  Load necessary modules --------
module load epyc/hdf5/1.14.6
module load epyc/ior/4.0.0

# --------  Standard Job Preamble for debuugging --------
section "SLURM JOB INFO"
log "Job ID:        ${SLURM_JOB_ID:-N/A}"
log "Node list:     ${SLURM_JOB_NODELIST:-N/A}"
log "Hostname:      $(hostname)"
log "Date:          $(date)"
log "Partition:     ${SLURM_JOB_PARTITION:-N/A}"

# --------- Main loop over scenarios and backends ---------
section "BENCHMARK RUN"

for backend in "${BACKENDS[@]}"; do
    section "BACKEND: ${backend}"

    for scenario in "${SCENARIOS[@]}"; do
        config_file="${CONFIG_DIR}/${scenario}.ini"
        summary_fname="${OUTPUT_DIR}/${backend,,}_${scenario}_${NNODES}nodes.out"

        for i in $(seq 1 "${N_ITER}"); do
			run_experiment \
				--slurm-job-id "${SLURM_JOB_ID:-N/A}" \
				--slurm-nodes "${SLURM_JOB_NODELIST:-N/A}" \
				--config-dir "${CONFIG_DIR}" \
				--output-dir "${OUTPUT_DIR}" \
				--n-iter "${i}" \
				--ntasks "${NTASKS}" \
				--backend "${backend,,}" \
				--scenario "${scenario}"

			# sleep between iterations to allow system to stabilize
			sleep "${SLEEP_DURATION}"
		done
    done
done

# echo -- sleep for 10 minutes to simulate idle
separator

QUERY="INSERT INTO experiments VALUES (now(), rnd_uuid4(), '$SLURM_JOB_ID', '$SLURM_JOB_NODELIST', 'START', 'IOR-idle');"
exec_query "$QUERY" "https://timeseriesdb.dev.rd.areasciencepark.it"
log "sleeping 10 minutes to have some idle metrics"
sleep 600
QUERY="INSERT INTO experiments VALUES (now(), rnd_uuid4(), '$SLURM_JOB_ID', '$SLURM_JOB_NODELIST', 'END', 'IOR-idle');"
exec_query "$QUERY" "https://timeseriesdb.dev.rd.areasciencepark.it"
section "FINISH"

