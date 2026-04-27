#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

# -------------------------------------------------------------------
# Polaris admin authentication
# -------------------------------------------------------------------
export POLARIS_BASE_URL="https://<YOUR_POLARIS_ENDPOINT>"                          # <-- TODO: replace this
export POLARIS_TOKEN_URL="${POLARIS_BASE_URL}/api/catalog/v1/oauth/tokens"
export POLARIS_REALM="POLARIS"
export POLARIS_ADMIN_CLIENT_ID="polaris_admin"
export POLARIS_ADMIN_CLIENT_SECRET="<YOUR_POLARIS_ADMIN_SECRET>"                   # <-- TODO: replace this

# -------------------------------------------------------------------
# Target catalog and RBAC objects
# -------------------------------------------------------------------
export CATALOG_NAME="hpc_observability"                                            # <-- TODO: adjust with your preferences
# Dedicated principal used by PyIceberg
export PRINCIPAL_NAME="pyiceberg_ingest"                                           # <-- TODO: adjust with your preferences
# Principal role granted to the principal
export PRINCIPAL_ROLE_NAME="pyiceberg_ingest_role"                                 # <-- TODO: adjust with your preferences
# Catalog role granted to the principal role
export CATALOG_ROLE_NAME="catalog_content_manager"                                 # <-- TODO: adjust with your preferences
# Output file for generated credentials
export OUTPUT_ENV_FILE="./polaris-pyiceberg-principal.env"                         # <-- TODO: adjust with your preferences

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
get_token() {
  curl -k -sS --fail \
    -u "${POLARIS_ADMIN_CLIENT_ID}:${POLARIS_ADMIN_CLIENT_SECRET}" \
    -H "Polaris-Realm: ${POLARIS_REALM}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "scope=PRINCIPAL_ROLE:ALL" \
    "${POLARIS_TOKEN_URL}" \
  | jq -r '.access_token'
}

request_json_allow_409() {
  local method="$1"
  local url="$2"
  local payload="${3:-}"

  local body_file
  body_file="$(mktemp)"
  local http_code

  if [[ -n "${payload}" ]]; then
    http_code="$(
      curl -k -sS \
        -o "${body_file}" \
        -w "%{http_code}" \
        -X "${method}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Polaris-Realm: ${POLARIS_REALM}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "${url}" \
        -d "${payload}"
    )"
  else
    http_code="$(
      curl -k -sS \
        -o "${body_file}" \
        -w "%{http_code}" \
        -X "${method}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Polaris-Realm: ${POLARIS_REALM}" \
        -H "Accept: application/json" \
        "${url}"
    )"
  fi

  if [[ "${http_code}" == "200" || "${http_code}" == "201" || "${http_code}" == "204" || "${http_code}" == "409" ]]; then
    cat "${body_file}"
    rm -f "${body_file}"
    return 0
  fi

  echo "Request failed: ${method} ${url}" >&2
  echo "HTTP status: ${http_code}" >&2
  cat "${body_file}" >&2
  rm -f "${body_file}"
  return 1
}

request_json_strict() {
  local method="$1"
  local url="$2"
  local payload="${3:-}"

  if [[ -n "${payload}" ]]; then
    curl -k -sS --fail \
      -X "${method}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Polaris-Realm: ${POLARIS_REALM}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "${url}" \
      -d "${payload}"
  else
    curl -k -sS --fail \
      -X "${method}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Polaris-Realm: ${POLARIS_REALM}" \
      -H "Accept: application/json" \
      "${url}"
  fi
}

# -------------------------------------------------------------------
# Start
# -------------------------------------------------------------------
TOKEN="$(get_token)"

echo "----- Creating principal role: ${PRINCIPAL_ROLE_NAME} -----"
request_json_allow_409 \
  "POST" \
  "${POLARIS_BASE_URL}/api/management/v1/principal-roles" \
  "$(jq -n --arg name "${PRINCIPAL_ROLE_NAME}" '{principalRole: {name: $name}}')" \
  | jq .

echo
echo "----- Creating catalog role: ${CATALOG_ROLE_NAME} on catalog ${CATALOG_NAME} -----"
request_json_allow_409 \
  "POST" \
  "${POLARIS_BASE_URL}/api/management/v1/catalogs/${CATALOG_NAME}/catalog-roles" \
  "$(jq -n --arg name "${CATALOG_ROLE_NAME}" '{catalogRole: {name: $name}}')" \
  | jq .

echo
echo "----- Granting CATALOG_MANAGE_CONTENT to catalog role ${CATALOG_ROLE_NAME} -----"
request_json_allow_409 \
  "PUT" \
  "${POLARIS_BASE_URL}/api/management/v1/catalogs/${CATALOG_NAME}/catalog-roles/${CATALOG_ROLE_NAME}/grants" \
  '{"grant":{"type":"catalog","privilege":"CATALOG_MANAGE_CONTENT"}}' \
  | jq .

echo
echo "----- Granting catalog role ${CATALOG_ROLE_NAME} to principal role ${PRINCIPAL_ROLE_NAME} -----"
request_json_allow_409 \
  "PUT" \
  "${POLARIS_BASE_URL}/api/management/v1/principal-roles/${PRINCIPAL_ROLE_NAME}/catalog-roles/${CATALOG_NAME}" \
  "$(jq -n --arg name "${CATALOG_ROLE_NAME}" '{catalogRole: {name: $name}}')" \
  | jq .

echo
echo "----- Creating principal ${PRINCIPAL_NAME} -----"

principal_payload="$(jq -n --arg name "${PRINCIPAL_NAME}" '{name: $name}')"

principal_response_file="$(mktemp)"
principal_http_code="$(
  curl -k -sS \
    -o "${principal_response_file}" \
    -w "%{http_code}" \
    -X "POST" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Polaris-Realm: ${POLARIS_REALM}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "${POLARIS_BASE_URL}/api/management/v1/principals" \
    -d "${principal_payload}"
)"

if [[ "${principal_http_code}" == "201" || "${principal_http_code}" == "200" ]]; then
  cat "${principal_response_file}" | jq .

  GENERATED_CLIENT_ID="$(jq -r '.credentials.clientId' < "${principal_response_file}")"
  GENERATED_CLIENT_SECRET="$(jq -r '.credentials.clientSecret' < "${principal_response_file}")"

  if [[ -z "${GENERATED_CLIENT_ID}" || "${GENERATED_CLIENT_ID}" == "null" || -z "${GENERATED_CLIENT_SECRET}" || "${GENERATED_CLIENT_SECRET}" == "null" ]]; then
    echo "Principal was created, but credentials were not returned." >&2
    rm -f "${principal_response_file}"
    exit 1
  fi

  umask 077
  cat > "${OUTPUT_ENV_FILE}" <<EOF
# Generated by 05-create-polaris-principal-and-grants.sh
export POLARIS_URI="${POLARIS_BASE_URL}/api/catalog"
export POLARIS_REALM="${POLARIS_REALM}"
export POLARIS_CATALOG_NAME="${CATALOG_NAME}"
export POLARIS_CLIENT_ID="${GENERATED_CLIENT_ID}"
export POLARIS_CLIENT_SECRET="${GENERATED_CLIENT_SECRET}"
export POLARIS_CREDENTIAL="${GENERATED_CLIENT_ID}:${GENERATED_CLIENT_SECRET}"
export POLARIS_SCOPE="PRINCIPAL_ROLE:ALL"
export POLARIS_PRINCIPAL_NAME="${PRINCIPAL_NAME}"
export POLARIS_PRINCIPAL_ROLE_NAME="${PRINCIPAL_ROLE_NAME}"
export POLARIS_CATALOG_ROLE_NAME="${CATALOG_ROLE_NAME}"
EOF
  chmod 600 "${OUTPUT_ENV_FILE}"

  echo
  echo "Credentials saved to: ${OUTPUT_ENV_FILE}"

elif [[ "${principal_http_code}" == "409" ]]; then
  echo "Principal ${PRINCIPAL_NAME} already exists." >&2
  echo "No new credentials were generated, so nothing was written to ${OUTPUT_ENV_FILE}." >&2
  echo "Use a new principal name, or delete/recreate the existing principal if you need fresh credentials." >&2
  cat "${principal_response_file}" >&2
  rm -f "${principal_response_file}"
  exit 1
else
  echo "Principal creation failed." >&2
  echo "HTTP status: ${principal_http_code}" >&2
  cat "${principal_response_file}" >&2
  rm -f "${principal_response_file}"
  exit 1
fi

rm -f "${principal_response_file}"

echo
echo "----- Granting principal role ${PRINCIPAL_ROLE_NAME} to principal ${PRINCIPAL_NAME} -----"
request_json_allow_409 \
  "PUT" \
  "${POLARIS_BASE_URL}/api/management/v1/principals/${PRINCIPAL_NAME}/principal-roles" \
  "$(jq -n --arg name "${PRINCIPAL_ROLE_NAME}" '{principalRole: {name: $name}}')" \
  | jq .

echo
echo "----- Final checks -----"
echo "Principal roles:"
request_json_strict \
  "GET" \
  "${POLARIS_BASE_URL}/api/management/v1/principal-roles" \
  | jq .

echo
echo "Catalog roles on ${CATALOG_NAME}:"
request_json_strict \
  "GET" \
  "${POLARIS_BASE_URL}/api/management/v1/catalogs/${CATALOG_NAME}/catalog-roles" \
  | jq .

echo
echo "Done."
echo "Use the credentials stored in $(realpath ${OUTPUT_ENV_FILE}) in your PyIceberg script."
