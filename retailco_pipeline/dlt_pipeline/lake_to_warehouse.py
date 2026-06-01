"""
RetailCo dlt Pipeline
=====================
Moves data from Lake PostgreSQL (raw schema) → Warehouse PostgreSQL (raw schema).

What dlt does:
- dlt (data load tool) is a Python library that handles the boring parts of loading data:
  schema inference, type coercion, incremental tracking, and idempotency.
- We define a "source" (lake DB) and a "destination" (warehouse DB).
- dlt tracks what it has already loaded using its own state table, so it only
  moves new or updated rows each run (incremental loading).
- It automatically handles type mismatches between source and destination.

Why not just copy the data manually?
- dlt gives us schema evolution (handles new columns), lineage, and built-in
  incremental cursors for free. It also integrates cleanly with Airflow.
"""

import os
import dlt
from dlt.sources.sql_database import sql_database


# Connection strings built from environment variables


LAKE_CONN_STR = (
    f"postgresql://{os.environ['LAKE_DB_USER']}:{os.environ['LAKE_DB_PASSWORD']}"
    f"@{os.environ['LAKE_DB_HOST']}:{os.environ.get('LAKE_DB_PORT', '5432')}"
    f"/{os.environ['LAKE_DB_NAME']}"
)

WAREHOUSE_CONN_STR = (
    f"postgresql://{os.environ['WAREHOUSE_DB_USER']}:{os.environ['WAREHOUSE_DB_PASSWORD']}"
    f"@{os.environ['WAREHOUSE_DB_HOST']}:{os.environ.get('WAREHOUSE_DB_PORT', '5432')}"
    f"/{os.environ['WAREHOUSE_DB_NAME']}"
)

# All 9 raw tables we need to move
ENTITIES = [
    "customers",
    "products",
    "stores",
    "employees",
    "orders",
    "order_items",
    "payments",
    "inventory_movements",
    "payment_methods",
]


def run_dlt_pipeline():
    """
    Main dlt pipeline function. Called by Airflow after the extractor finishes.

    Steps:
    1. Connect to the lake DB as a SQL source.
    2. For each table, use 'updated_at' as the incremental cursor, dlt remembers
       the last value it saw and only fetches newer rows next time.
    3. Write to the warehouse DB under the 'raw' schema.
    4. dlt handles type coercion: e.g., JSONB in lake becomes proper typed columns
       in the warehouse (it inspects the JSONB and flattens it).
    """

    # Define the pipeline: name, destination, and which schema to write into
    pipeline = dlt.pipeline(
        pipeline_name="retailco_lake_to_warehouse",
        destination=dlt.destinations.postgres(WAREHOUSE_CONN_STR),
        dataset_name="raw",          # writes to warehouse.raw schema
    )

    # Define the source: read from lake DB, raw schema
    # incremental_cursor_path="updated_at" tells dlt to track progress per table
    source = sql_database(
        credentials=LAKE_CONN_STR,
        schema="raw",
        table_names=ENTITIES,
        incremental=dlt.sources.incremental(
            "updated_at",
            on_cursor_value_missing="include",
        ),
    )

    # Run dlt and figures out what's new and loads it.
    load_info = pipeline.run(source)

    print(load_info)

    # Check for load errors
    if load_info.has_failed_jobs:
        raise RuntimeError(f"dlt pipeline had failed jobs: {load_info}")

    print("dlt pipeline completed successfully!")
    return load_info


if __name__ == "__main__":
    run_dlt_pipeline()
