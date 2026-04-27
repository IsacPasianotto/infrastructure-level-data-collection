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
#SBATCH --time=04:00:00
#SBATCH --job-name=bnchk
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
SCALE=100
SEED=123
LOG_INTERVAL="1s"
START_TIMESTAMP="2025-01-01T00:00:00Z"
END_TIMESTAMP="2025-01-07T00:00:00Z"
DATA_FOLDER="/orfeo/cephfs/scratch/dssc/ipasia00/timeseriesdata"               # <-- TODO: change this accordingly to your cluster


# ------------ Main script ------------

# ensure that tsbs_generate_data is available
if ! command -v tsbs_generate_data &> /dev/null
then
    echo "tsbs_generate_data could not be found. Please load the appropriate module or install it."
    exit
fi

mkdir -p $DATA_FOLDER

# --QuestDB
echo " -- Generating QuestDB data -- "
tsbs_generate_data \
  --format=questdb \
  --use-case=devops \
  --scale=$SCALE \
  --seed=$SEED \
  --log-interval=$LOG_INTERVAL \
  --timestamp-start=$START_TIMESTAMP \
  --timestamp-end=$END_TIMESTAMP \
  > $DATA_FOLDER/dataquest.gz

# -- TimescaleDB
echo " -- Generating TimescaleDB data -- "
tsbs_generate_data \
  --format=timescaledb \
  --use-case=devops \
  --scale=$SCALE \
  --seed=$SEED \
  --log-interval=$LOG_INTERVAL \
  --timestamp-start=$START_TIMESTAMP \
  --timestamp-end=$END_TIMESTAMP \
  > $DATA_FOLDER/datatimescale.gz

# -- InfluxDB
echo " -- Generating InfluxDB data -- "
tsbs_generate_data \
  --format=influx \
  --use-case=devops \
  --scale=$SCALE \
  --seed=$SEED \
  --log-interval=$LOG_INTERVAL \
  --timestamp-start=$START_TIMESTAMP \
  --timestamp-end=$END_TIMESTAMP \
  > $DATA_FOLDER/datainflux.gz

# Check that files were created and their sizes
echo " -- Checking content of $DATA_FOLDER -- "
ls -lh $DATA_FOLDER | grep data*.gz

echo "---------------------------------------------"
echo "Done!"
echo "DATE: $(date)"
echo "It took $SECONDS seconds"
echo "---------------------------------------------"
