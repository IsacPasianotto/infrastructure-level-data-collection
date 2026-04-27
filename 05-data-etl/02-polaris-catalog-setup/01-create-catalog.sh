#!/bin/bash

# SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
# SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

# -------------------------------------------------------------------
# Polaris admin authentication
# -------------------------------------------------------------------
export POLARIS_BASE_URL="https://<YOUR_POLARIS_ENDPOINT>"                       # <-- TODO: replace this
export POLARIS_TOKEN_URL="${POLARIS_BASE_URL}/api/catalog/v1/oauth/tokens"
export POLARIS_REALM="POLARIS"
export POLARIS_CLIENT_ID="polaris_admin"
export POLARIS_CLIENT_SECRET="<YOUR_POLARIS_ADMIN_SECRET>"                      # <-- TODO: replace this

# -------------------------------------------------------------------
# Catalog settings
# -------------------------------------------------------------------
export CATALOG_NAME="hpc_observability"                                        # <-- TODO: adjust with your preferences
export DEFAULT_BASE_LOCATION="s3://hpc-observability-dataset/iceberg/".        # <-- TODO: adjust with your preferences 
# Allowed locations:
# - Iceberg metadata lives under iceberg/
# - Existing parquet data lives under raw/
export ALLOWED_LOCATION_1="s3://hpc-observability-dataset/iceberg/"            # <-- TODO: adjust with your preferences
export ALLOWED_LOCATION_2="s3://hpc-observability-dataset/raw/"                # <-- TODO: adjust with your preferences

# S3-compatible endpoint
export S3_ENDPOINT="https://<YOUR_S3_COMPATIBLE_ENDPOINT>"                          # <-- TODO: replace this
export S3_ENDPOINT_INTERNAL="https://<YOUR_S3_COMPATIBLE_ENDPOINT_INTERNAL>"        # <-- TODO: replace this 
# Static S3 credentials used by Polaris for Ceph / S3-compatible access
export S3_ACCESS_KEY_ID="<YOUR_S3_ACCESS_KEY_ID>"                                   # <-- TODO: replace this
export S3_SECRET_ACCESS_KEY="<YOUR_S3_SECRET_ACCESS_KEY>"                           # <-- TODO: replace this

# Optional but often useful with S3 clients
export S3_REGION="eu-south-1"                                                       # <-- TODO: replace this


# -------------------------------------------------------------------
# Step 1: Get admin token
# -------------------------------------------------------------------
TOKEN="$(
  curl -k -sS --fail \
    -u "${POLARIS_CLIENT_ID}:${POLARIS_CLIENT_SECRET}" \
    -H "Polaris-Realm: ${POLARIS_REALM}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "scope=PRINCIPAL_ROLE:ALL" \
    "${POLARIS_TOKEN_URL}" \
  | jq -r '.access_token'
)"

# -------------------------------------------------------------------
# Step 2: Build catalog payload
# -------------------------------------------------------------------
PAYLOAD="$(
  jq -n \
    --arg catalog_name "${CATALOG_NAME}" \
    --arg default_base_location "${DEFAULT_BASE_LOCATION}" \
    --arg allowed_location_1 "${ALLOWED_LOCATION_1}" \
    --arg allowed_location_2 "${ALLOWED_LOCATION_2}" \
    --arg s3_endpoint "${S3_ENDPOINT}" \
    --arg s3_endpoint_internal "${S3_ENDPOINT_INTERNAL}" \
    --arg s3_access_key_id "${S3_ACCESS_KEY_ID}" \
    --arg s3_secret_access_key "${S3_SECRET_ACCESS_KEY}" \
    --arg s3_region "${S3_REGION}" \
    '{
      catalog: {
        name: $catalog_name,
        type: "INTERNAL",
        readOnly: false,
        properties: {
          "default-base-location": $default_base_location,
          "s3.access-key-id": $s3_access_key_id,
          "s3.secret-access-key": $s3_secret_access_key,
          "client.region": $s3_region
        },
        storageConfigInfo: {
          storageType: "S3",
          allowedLocations: [
            $allowed_location_1,
            $allowed_location_2
          ],
          endpoint: $s3_endpoint,
          endpointInternal: $s3_endpoint_internal,
          pathStyleAccess: true,
          stsUnavailable: true
        }
      }
    }'
)"

#-------------------------------------------------------------------
# Step 3: perform the API call to create the catalog
#-------------------------------------------------------------------

echo "----- Payload sent to Polaris -----"
echo "${PAYLOAD}" | jq .

echo
echo "----- Creating catalog ${CATALOG_NAME} -----"
curl -k -sS --fail \
  -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Polaris-Realm: ${POLARIS_REALM}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "${POLARIS_BASE_URL}/api/management/v1/catalogs" \
  -d "${PAYLOAD}" | jq
