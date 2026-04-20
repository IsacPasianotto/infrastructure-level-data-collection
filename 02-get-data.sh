#!/bin/bash

set -euo pipefail

# --------- Constants ---------
DATA_INDEX_URL="https://doi.org/10.5281/zenodo.19468082"
# ------------------------------

CMDS=(
    curl
    jq
    md5sum
)
for cmd in "${CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it and try again." >&2
        exit 1
    fi
done

# --------- function definitions ---------
function download_zenodo_parquet() {
    local record_id="$1"
    local outdir="$2"

    if [[ -z "${record_id}" || -z "${outdir}" ]]; then
        echo "Usage: download_zenodo_parquet <record-id> <output-dir>" >&2
        return 2
    fi
    mkdir -p "${outdir}" || return 1

    while IFS=$'\t' read -r filename url checksum; do
        echo "Downloading $filename"
        curl -fL --retry 5 --retry-delay 2 -o "${outdir}/${filename}" "$url" || return 1

        # --- Verify the checksum
        local expected actual
        expected="${checksum#md5:}"
        actual="$(md5sum "${outdir}/${filename}" | awk '{print $1}')" || return 1

        if [[ "$expected" != "$actual" ]]; then
            echo "Checksum mismatch for ${filename}" >&2
            return 1
        fi
    done < <(
        curl -fsSL "https://zenodo.org/api/records/${record_id}" \
          | jq -r '.files[]
                   | select(.key | endswith(".parquet"))
                   | [.key, .links.self, .checksum]
                   | @tsv'
    )
}

function doi_to_record_id() {
    local doi="$1"

    if [[ -z "${doi}" ]]; then
        echo "Usage: doi_to_record_id <doi>" >&2
        return 2
    fi

    awk -F. '{print $NF}' <<< "${doi}"
}
# ---------- End of function definitions ---------


# ---------------- Main script --------------------
PRJ_DIR=$(git rev-parse --show-toplevel)
DATA_DIR="${PRJ_DIR}/data"

mkdir -p "${DATA_DIR}"
pushd "${DATA_DIR}" > /dev/null || exit

# retrieve the index of all file to download
record_id=$(doi_to_record_id "${DATA_INDEX_URL}")
if [[ -z "$record_id" ]]; then
    echo "Error: Failed to retrieve record ID from ${DATA_INDEX_URL}" >&2
    exit 1
fi

dataset_index_url="$(
  curl -fsSL "https://zenodo.org/api/records/${record_id}" \
    | jq -r '.files[]
             | select(.key == "dataset_index.json")
             | .links.self'
)"
dataset_index_json="$(curl -fsSL "${dataset_index_url}")"


# debug
# echo "${dataset_index_json}" | jq

# parse the dataset index and download parquet files in an ordered structure:
while IFS=$'\t' read -r table label doi; do
    table_dir="${DATA_DIR}/${table}"
    table_record_id="$(doi_to_record_id "${doi}")"

    echo "Processing table=${table}, label=${label}, doi=${doi}"
    download_zenodo_parquet "${table_record_id}" "${table_dir}"
done < <(
    echo "${dataset_index_json}" | jq -r '
        .tables
        | to_entries[]
        | .key as $table
        | .value.zenodo_records[]
        | [$table, .label, .doi]
        | @tsv
    '
)

popd > /dev/null || exit # Return to the original directory