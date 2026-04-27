#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export ICEBERG_CATALOG_CREDENTIAL="polaris_admin:<your-admin-client-secret>"        # <-- TODO: adjust it
export POLARIS_BASE_URL="<your-polaris-base-url>"                                   # <-- TODO: adjust it
export POLARIS_REALM="POLARIS"
export POLARIS_MANAGEMENT_URL="${POLARIS_BASE_URL}/api/management/v1"
export POLARIS_TOKEN_URL="${POLARIS_BASE_URL}/api/catalog/v1/oauth/tokens"

CATALOG="<your-catalog-name>"                               # <-- TODO: adjust it
NAMESPACE="<your-namespace>"                                # <-- TODO: adjust it
PRINCIPAL="guest"
PRINCIPAL_ROLE="guest_ro"
CATALOG_ROLE="guests_reader"


PRJ_ROOT_DIR=$(git rev-parse --show-toplevel)
FILE_OUT="${PRJ_ROOT_DIR}/05-data-etl/06-query-catalog-example/read-only-user-creds.env"


# List of tables to grant access to. Adjust as needed.
TABLES=(
  "cpu"
  "diskio"
  "energy_meter"
  "infiniband"
  "ipmi_power"
  "ipmi_sensor"
  "mem"
  "net"
  "nvidia_smi"
  "pdu_power"
  "turbostat"
  "llm_api_usage"
  "slurm_job_table"
)

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

TOKEN="$(
  curl -k -sS --fail \
    -u "${ICEBERG_CATALOG_CREDENTIAL}" \
    -H "Polaris-Realm: ${POLARIS_REALM}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "scope=PRINCIPAL_ROLE:ALL" \
    "${POLARIS_TOKEN_URL}" | jq -r '.access_token'
)"

api_json() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  if [[ -n "$data" ]]; then
    curl -k -sS \
      -o /tmp/polaris-body.json \
      -w "%{http_code}" \
      -X "$method" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Polaris-Realm: ${POLARIS_REALM}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      "$url" \
      -d "$data"
  else
    curl -k -sS \
      -o /tmp/polaris-body.json \
      -w "%{http_code}" \
      -X "$method" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Polaris-Realm: ${POLARIS_REALM}" \
      -H "Accept: application/json" \
      "$url"
  fi
}

ok_or_conflict() {
  local step="$1"
  local code="$2"

  case "$code" in
    200|201|204|409)
      echo "${step}: ${code}"
      ;;
    *)
      echo "${step}: ${code}" >&2
      echo "--- response body ---" >&2
      cat /tmp/polaris-body.json >&2 || true
      exit 1
      ;;
  esac
}

grant_or_die() {
  local description="$1"
  local payload="$2"

  local code
  code="$(
    api_json PUT \
      "${POLARIS_MANAGEMENT_URL}/catalogs/${CATALOG}/catalog-roles/${CATALOG_ROLE}/grants" \
      "$payload"
  )"

  case "$code" in
    200|201|204|409)
      echo "  ${description}: ${code}"
      ;;
    *)
      echo "  ${description}: ${code}" >&2
      echo "--- failing payload ---" >&2
      echo "$payload" >&2
      echo "--- response body ---" >&2
      cat /tmp/polaris-body.json >&2 || true
      exit 1
      ;;
  esac
}

echo "1) create principal if missing"
code="$(
  api_json POST \
    "${POLARIS_MANAGEMENT_URL}/principals" \
    "$(jq -nc --arg n "${PRINCIPAL}" '{principal:{name:$n}}')"
)"
ok_or_conflict "create principal" "$code"

echo "2) reset credentials and save them"
code="$(
  api_json POST \
    "${POLARIS_MANAGEMENT_URL}/principals/${PRINCIPAL}/reset" \
    '{}'
)"
case "$code" in
  200)
    echo "reset credentials: ${code}"
    ;;
  *)
    echo "reset credentials: ${code}" >&2
    cat /tmp/polaris-body.json >&2 || true
    exit 1
    ;;
esac

CLIENT_ID="$(jq -r '.credentials.clientId' /tmp/polaris-body.json)"
CLIENT_SECRET="$(jq -r '.credentials.clientSecret' /tmp/polaris-body.json)"

cat > "${FILE_OUT}" <<EOF
export CLIENT_ID="${CLIENT_ID}"
export CLIENT_SECRET="${CLIENT_SECRET}"
export CATALOG_WAREHOUSE="${CATALOG}"
export ICEBERG_NAMESPACE="${NAMESPACE}"
export CATALOG_CREDENTIAL="${CLIENT_ID}:${CLIENT_SECRET}"
export CATALOG_SCOPE="PRINCIPAL_ROLE:ALL"
EOF

chmod 600 ${FILE_OUT}

echo "3) create principal role if missing"
code="$(
  api_json POST \
    "${POLARIS_MANAGEMENT_URL}/principal-roles" \
    "$(jq -nc --arg n "${PRINCIPAL_ROLE}" '{principalRole:{name:$n}}')"
)"
ok_or_conflict "create principal role" "$code"

echo "4) assign principal role to principal"
code="$(
  api_json PUT \
    "${POLARIS_MANAGEMENT_URL}/principals/${PRINCIPAL}/principal-roles" \
    "$(jq -nc --arg n "${PRINCIPAL_ROLE}" '{principalRole:{name:$n}}')"
)"
ok_or_conflict "assign principal role" "$code"

echo "5) create catalog role if missing"
code="$(
  api_json POST \
    "${POLARIS_MANAGEMENT_URL}/catalogs/${CATALOG}/catalog-roles" \
    "$(jq -nc --arg n "${CATALOG_ROLE}" '{catalogRole:{name:$n}}')"
)"
ok_or_conflict "create catalog role" "$code"

echo "6) assign catalog role to principal role"
code="$(
  api_json PUT \
    "${POLARIS_MANAGEMENT_URL}/principal-roles/${PRINCIPAL_ROLE}/catalog-roles/${CATALOG}" \
    "$(jq -nc --arg n "${CATALOG_ROLE}" '{catalogRole:{name:$n}}')"
)"
ok_or_conflict "assign catalog role" "$code"

echo "7) grant catalog-level read"
grant_or_die \
  "grant CATALOG_READ_PROPERTIES" \
  "$(jq -nc '{grant:{type:"catalog", privilege:"CATALOG_READ_PROPERTIES"}}')"

echo "8) grant namespace-level read/list on ${NAMESPACE}"
grant_or_die \
  "grant NAMESPACE_LIST" \
  "$(jq -nc --arg ns "${NAMESPACE}" \
    '{grant:{type:"namespace", namespace:[$ns], privilege:"NAMESPACE_LIST"}}')"

grant_or_die \
  "grant NAMESPACE_READ_PROPERTIES" \
  "$(jq -nc --arg ns "${NAMESPACE}" \
    '{grant:{type:"namespace", namespace:[$ns], privilege:"NAMESPACE_READ_PROPERTIES"}}')"

grant_or_die \
  "grant TABLE_LIST" \
  "$(jq -nc --arg ns "${NAMESPACE}" \
    '{grant:{type:"namespace", namespace:[$ns], privilege:"TABLE_LIST"}}')"

echo "9) grant table-level read on selected tables"
for TABLE in "${TABLES[@]}"; do
  echo "  table ${NAMESPACE}.${TABLE}"

  grant_or_die \
    "grant TABLE_READ_PROPERTIES on ${NAMESPACE}.${TABLE}" \
    "$(jq -nc --arg ns "${NAMESPACE}" --arg table "${TABLE}" \
      '{grant:{type:"table", namespace:[$ns], tableName:$table, privilege:"TABLE_READ_PROPERTIES"}}')"

  grant_or_die \
    "grant TABLE_READ_DATA on ${NAMESPACE}.${TABLE}" \
    "$(jq -nc --arg ns "${NAMESPACE}" --arg table "${TABLE}" \
      '{grant:{type:"table", namespace:[$ns], tableName:$table, privilege:"TABLE_READ_DATA"}}')"
done

echo "10) show grants"
code="$(
  api_json GET \
    "${POLARIS_MANAGEMENT_URL}/catalogs/${CATALOG}/catalog-roles/${CATALOG_ROLE}/grants"
)"
case "$code" in
  200)
    jq . /tmp/polaris-body.json
    ;;
  *)
    echo "list grants: ${code}" >&2
    cat /tmp/polaris-body.json >&2 || true
    exit 1
    ;;
esac

echo
echo "Done."
echo "Principal: ${PRINCIPAL}"
echo "Principal role: ${PRINCIPAL_ROLE}"
echo "Catalog role: ${CATALOG_ROLE}"
echo "Namespace: ${NAMESPACE}"
printf 'Tables: %s\n' "${TABLES[@]}"
echo
echo "Notebook credential:"
echo "${CLIENT_ID}:${CLIENT_SECRET}"
echo
echo "Saved to ${FILE_OUT}"
