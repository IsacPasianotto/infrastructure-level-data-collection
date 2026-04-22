#!/usr/bin/env python3

# -------- Imports --------
import sys
from pathlib import Path
import os

import requests
import urllib3
import pyarrow as pa
import pyarrow.parquet as pq

from pyiceberg.catalog import load_catalog
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.schema import Schema
from pyiceberg.transforms import DayTransform
from pyiceberg.types import (
    NestedField,
    BooleanType,
    IntegerType,
    LongType,
    FloatType,
    DoubleType,
    StringType,
    DateType,
    TimestampType,
    TimestamptzType,
)


# -----  TLS bypass for development environments with self-signed certificates  ---
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
_old_request = requests.Session.request
def _patched_request(self, *args, **kwargs):
    kwargs.setdefault("verify", False)
    return _old_request(self, *args, **kwargs)
requests.Session.request = _patched_request



# --------- Polairis Catalog Configuration ---------
def require_env(name: str, *, transform=str) -> object:
    value = os.environ.get(name)
    if value is None or value.strip() == "":
        print(f"Error: required environment variable '{name}' is not set.", file=sys.stderr)
        sys.exit(1)

    try:
        return transform(value)
    except Exception as exc:
        print(
            f"Error: environment variable '{name}' has invalid value {value!r}: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)

# Read all the required configuration from environment variables
POLARIS_URI = require_env("POLARIS_URI")
POLARIS_CATALOG_NAME = require_env("POLARIS_CATALOG_NAME")
POLARIS_REALM = require_env("POLARIS_REALM")
NAMESPACE = require_env("NAMESPACE")
ICEBERG_S3_ROOT = require_env("ICEBERG_S3_ROOT")
POLARIS_CLIENT_ID = require_env("POLARIS_CLIENT_ID")
POLARIS_CLIENT_SECRET = require_env("POLARIS_CLIENT_SECRET")
# S3 / Ceph
S3_ENDPOINT = require_env("S3_ENDPOINT")
S3_ACCESS_KEY = require_env("S3_ACCESS_KEY")
S3_SECRET_KEY = require_env("S3_SECRET_KEY")
S3_REGION = require_env("S3_REGION")
# Timestamp column name
TIMESTAMP_COLUMN = "timestamp"


# ------------- Helper functions -------------

def prompt_user_choice() -> str:
    print()
    print("The target Iceberg table already exists.")
    print("Choose one action:")
    print("  [s] skip      - do nothing and exit")
    print("  [r] replace   - drop and recreate the table, then re-import all files")
    print()

    while True:
        choice = input("Your choice [s/r]: ").strip().lower()
        if choice in {"s", "skip"}:
            return "skip"
        if choice in {"r", "replace"}:
            return "replace"
        print("Invalid choice. Please enter s or r.")


def create_or_load_catalog():
    return load_catalog(
        "polaris",
        type="rest",
        uri=POLARIS_URI,
        warehouse=POLARIS_CATALOG_NAME,
        credential=f"{POLARIS_CLIENT_ID}:{POLARIS_CLIENT_SECRET}",
        scope="PRINCIPAL_ROLE:ALL",
        **{
            "header.Polaris-Realm": POLARIS_REALM,
            "header.X-Iceberg-Access-Delegation": "",
            "py-io-impl": "pyiceberg.io.pyarrow.PyArrowFileIO",
            "s3.endpoint": S3_ENDPOINT,
            "s3.access-key-id": S3_ACCESS_KEY,
            "s3.secret-access-key": S3_SECRET_KEY,
            "s3.region": S3_REGION,
            "s3.resolve-region": "false",
            "s3.force-virtual-addressing": "false",
        },
    )

def ensure_namespace_exists(catalog):
    try:
        catalog.create_namespace(NAMESPACE)
        print(f"Namespace created: {NAMESPACE}")
    except Exception:
        print(f"Namespace already exists or could not be created: {NAMESPACE}")


def pa_field_to_iceberg(field: pa.Field, field_id: int) -> NestedField:
    t = field.type
    if pa.types.is_boolean(t):
        iceberg_type = BooleanType()
    elif pa.types.is_int8(t) or pa.types.is_int16(t) or pa.types.is_int32(t):
        iceberg_type = IntegerType()
    elif pa.types.is_int64(t):
        iceberg_type = LongType()
    elif pa.types.is_float32(t):
        iceberg_type = FloatType()
    elif pa.types.is_float64(t):
        iceberg_type = DoubleType()
    elif pa.types.is_string(t) or pa.types.is_large_string(t):
        iceberg_type = StringType()
    elif pa.types.is_date32(t):
        iceberg_type = DateType()
    elif pa.types.is_timestamp(t):
        if getattr(t, "tz", None) is not None:
            iceberg_type = TimestamptzType()
        else:
            iceberg_type = TimestampType()
    else:
        raise NotImplementedError(
            f"Arrow type not supported yet for field '{field.name}': {t}"
        )

    return NestedField(
        field_id=field_id,
        name=field.name,
        field_type=iceberg_type,
        required=not field.nullable,
    )


def arrow_schema_to_iceberg_schema(arrow_schema: pa.Schema) -> Schema:
    fields = []
    next_field_id = 1

    for field in arrow_schema:
        fields.append(pa_field_to_iceberg(field, next_field_id))
        next_field_id += 1

    return Schema(*fields)


def validate_arrow_schema_supported(arrow_schema: pa.Schema):
    unsupported = []
    for idx, field in enumerate(arrow_schema, start=1):
        try:
            pa_field_to_iceberg(field, idx)
        except NotImplementedError as e:
            unsupported.append(str(e))

    if unsupported:
        print("Unsupported Arrow types detected:")
        for msg in unsupported:
            print(f"  - {msg}")
        raise SystemExit(1)


def validate_timestamp_column(arrow_schema: pa.Schema, column_name: str):
    if column_name not in arrow_schema.names:
        raise ValueError(
            f"Required timestamp column '{column_name}' not found. "
            f"Available columns: {arrow_schema.names}"
        )

    field = arrow_schema.field(column_name)
    if not pa.types.is_timestamp(field.type):
        raise ValueError(
            f"Column '{column_name}' must be a timestamp, found: {field.type}"
        )

def create_partitioned_table(catalog, identifier: str, iceberg_schema: Schema, table_location: str):
    ts_field = iceberg_schema.find_field(TIMESTAMP_COLUMN)

    partition_spec = PartitionSpec(
        fields=(
            PartitionField(
                source_id=ts_field.field_id,
                field_id=1000,
                transform=DayTransform(),
                name=f"{TIMESTAMP_COLUMN}_day",
            ),
        )
    )

    return catalog.create_table(
        identifier=identifier,
        schema=iceberg_schema,
        location=table_location,
        partition_spec=partition_spec,
    )

def load_or_create_table(catalog, identifier: str, iceberg_schema: Schema, table_location: str):
    try:
        table = catalog.load_table(identifier)
        print(f"Table already exists: {identifier}")

        choice = prompt_user_choice()
        if choice == "skip":
            print("Operation skipped by user.")
            sys.exit(0)

        print("Dropping and recreating the table...")
        catalog.drop_table(identifier)
        table = create_partitioned_table(catalog, identifier, iceberg_schema, table_location)
        print(f"Table recreated: {identifier}")
        return table

    except Exception:
        table = create_partitioned_table(catalog, identifier, iceberg_schema, table_location)
        print(f"Table created: {identifier}")
        return table

# ---------------- Main logic ----------------

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <folder>")
        print(f"Example: {sys.argv[0]} cpu")
        sys.exit(1)

    folder = sys.argv[1].strip()
    local_dir = Path(folder)

    if not local_dir.exists() or not local_dir.is_dir():
        print(f"Error: directory not found: {local_dir}")
        sys.exit(1)

    parquet_files = sorted(local_dir.glob("*.parquet"))
    if not parquet_files:
        print(f"Error: no .parquet files found in {local_dir}")
        sys.exit(1)

    first_file = parquet_files[0]

    identifier = f"{NAMESPACE}.{folder}"
    # Polaris enforces the catalog's allowed base prefix, which includes a
    # relative `./` segment for namespace-scoped table locations.
    table_location = f"{ICEBERG_S3_ROOT.rstrip('/')}/{NAMESPACE}/{folder}"
    print(f"Folder: {folder}")
    print(f"Local directory: {local_dir}")
    print(f"First file used for schema inference: {first_file}")
    print(f"Target Iceberg table: {identifier}")
    print(f"Table metadata location: {table_location}")
    print(f"Number of parquet files found: {len(parquet_files)}")

    base_arrow_schema = pq.read_schema(first_file)

    validate_timestamp_column(base_arrow_schema, TIMESTAMP_COLUMN)
    validate_arrow_schema_supported(base_arrow_schema)

    iceberg_schema = arrow_schema_to_iceberg_schema(base_arrow_schema)

    print()
    print("Inferred Iceberg schema:")
    print(iceberg_schema)

    catalog = create_or_load_catalog()
    ensure_namespace_exists(catalog)

    table = load_or_create_table(catalog, identifier, iceberg_schema, table_location)

    print()
    print(f"Importing parquet files into Iceberg partitioned by day({TIMESTAMP_COLUMN})...")

    imported_files = 0
    imported_rows = 0

    for parquet_file in parquet_files:
        print(f"Reading local parquet: {parquet_file}")

        arrow_table = pq.read_table(parquet_file)

        table.append(
            arrow_table,
            snapshot_properties={
                "source-file": parquet_file.name,
            },
        )

        imported_files += 1
        imported_rows += arrow_table.num_rows

    print()
    print("Import completed successfully.")
    print(f"Imported files: {imported_files}")
    print(f"Imported rows:  {imported_rows}")
    print(f"Target table:   {identifier}")

    refreshed_table = catalog.load_table(identifier)
    print()
    print("Current partition spec:")
    print(refreshed_table.spec())

    print()
    print("Sample planned files from a full scan:")
    tasks = list(refreshed_table.scan().plan_files())
    print(f"Planned files: {len(tasks)}")
    for task in tasks[:5]:
        print("file:", task.file.file_path)
        print("partition:", task.file.partition)
        print("---")


if __name__ == "__main__":
    main()