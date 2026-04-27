#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

#SBATCH -A <your_account>                      # <-- TODO: adjust to your account
#SBATCH -p <your_partition>                    # <-- TODO: adjust to your partition
#SBATCH --nodes=1
#SBATCH --mem=126G
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --time=6:00:00
#SBATCH --job-name=polaris-load-data
#SBATCH --get-user-env
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

# ----- CONSTANTS: -------
ROOT_PRJ_DIR=$(git rev-parse --show-toplevel)
DATA_DIR="${ROOT_PRJ_DIR}/questdb-parquet-data"
SCRIPT_DIR="${ROOT_PRJ_DIR}/05-data-etl/05-load-data"
PYTHON_SCRIPT="${SCRIPT_DIR}/load_data.py"

ENV_DIR=${ROOT_PRJ_DIR}/.venv                                   # <-- TODO: adjust to your env dir


# Activate the python environment
source ${ENV_DIR}/bin/activate

# source .env                                                   # <-- TODO: adjust to your .env or define the variables directly in the shell

NEEDED_VARS=(
    BUCKET_NAME
    POLARIS_URI
    POLARIS_CATALOG_NAME
    POLARIS_REALM
    NAMESPACE
    ICEBERG_S3_ROOT
    POLARIS_CLIENT_ID
    POLARIS_CLIENT_SECRET
    S3_ENDPOINT
    S3_ACCESS_KEY
    S3_SECRET_KEY
    S3_REGION
)

for var in "${NEEDED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Environment variable $var is not set. Please set it before running this script."
        exit 1
    fi
done

to_process=$(ls ${DATA_DIR}/)

# go to the data directory and run the python script for each folder
pushd ${DATA_DIR} > /dev/null || exit 1
for folder in ${to_process}; do

    echo "+++++++++++ Processing folder: ${folder} +++++++++++"
    python ${PYTHON_SCRIPT} ${folder}
done

popd > /dev/null || exit 1


