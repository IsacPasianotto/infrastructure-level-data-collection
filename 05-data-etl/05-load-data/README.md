<!--
SPDX-FileCopyrightText: 2026 Isac Pasianotto <isac.pasianotto@phd.units.it>
SPDX-FileCopyrightText: 2026 Niccolo Tosato <niccolo.tosato@phd.units.it>

SPDX-License-Identifier: CC-BY-4.0
-->

# Loading data into the data catalog

Before to start, if the bucket in which you want to store the data is not created yet, make sure it exists by running the following command (replace `<bucket-name>` with the name of the bucket you want to create):

```bash
export AWS_ACCESS_KEY_ID="<access-key-id>"
export AWS_SECRET_ACCESS_KEY="<secret-access-key>"
export AWS_DEFAULT_REGION="eu-south-1"
export AWS_ENDPOINT_URL="https://buckets.areasciencepark.it"

aws --endpoint-url "$AWS_ENDPOINT_URL" \
    s3 mb s3://<bucket-name>
```

Then you can use the `runme.sh` script to iteratively launch the `load_data.py` for each folder contained in the `data/` directory.

In order to work properly, the python script need some env variables to be setted.
You can either create a `.env` file and source it in the bash script, or edit the `runme.sh` script to export the required env variables before to launch the `load_data.py` script.

The complete list of required env variables is the following (replace the placeholder values with the actual configuration):


```bash 
export BUCKET_NAME="<bucket-name>"
export POLARIS_URI="https://<polaris-uri>/api/catalog"
export POLARIS_CATALOG_NAME="${BUCKET_NAME}"
export POLARIS_REALM="POLARIS"
export NAMESPACE="raws"
export ICEBERG_S3_ROOT="s3://${BUCKET_NAME}/iceberg"
export POLARIS_CLIENT_ID="<polaris-client-id>"
export POLARIS_CLIENT_SECRET="<polaris-client-secret>"
export DEFAULT_BASE_LOCATION="s3://${BUCKET_NAME}/iceberg/"
# S3 / Ceph
export S3_ENDPOINT="<s3-endpoint>"
export S3_ACCESS_KEY="<access-key-id>"
export S3_SECRET_KEY="<secret-key>"
export S3_REGION="eu-south-1"
```


