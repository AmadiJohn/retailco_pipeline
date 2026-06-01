"""
RetailCo Master Pipeline DAG
=============================
This is the top-level Airflow DAG that orchestrates everything.

What Airflow does (plain English):
- Airflow is a scheduler. Think of it like a smart alarm clock for code.
- You define TASKS and the ORDER they must run (dependencies).
- If a task fails, Airflow retries it automatically (with backoff).
- You can look at a web UI to see which tasks passed, failed, or are running.
- You can also "backfill" — run it for past dates if you missed some.

Task Order:
  extract_* (9 tasks in parallel)
      ↓
  dlt_load
      ↓
  dbt_snapshot (SCD2 snapshots)
      ↓
  dbt_staging (all stg_ models)
      ↓
  dbt_marts (all dim_ and fct_ models)
      ↓
  dbt_test (validates all models pass data quality checks)

If ANY task fails → all downstream tasks are blocked (no silent partial runs).
"""

import os
import subprocess
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago

# ──────────────────────────────────────────────
# Default task settings
# ──────────────────────────────────────────────
DEFAULT_ARGS = {
    "owner": "retailco_data_team",
    "depends_on_past": False,           # each daily run is independent
    "start_date": datetime(2024, 1, 1), # backfill-capable from this date
    "email_on_failure": False,
    "retries": 2,                        # retry every failed task twice
    "retry_delay": timedelta(minutes=5), # wait 5 min between retries
    "retry_exponential_backoff": True,   # 5min → 10min → 20min
}

# ──────────────────────────────────────────────
# dbt helper: runs a dbt command inside the container
# ──────────────────────────────────────────────
DBT_DIR = "/opt/airflow/dbt_project"
DBT_PROFILES_DIR = "/opt/airflow/dbt_project"

def run_dbt(command: str):
    """Run a dbt command and raise on failure."""
    full_command = f"dbt {command} --profiles-dir {DBT_PROFILES_DIR} --project-dir {DBT_DIR}"
    result = subprocess.run(full_command, shell=True, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError(f"dbt command failed: {full_command}\n{result.stderr}")
    return result.stdout


# ──────────────────────────────────────────────
# Extractor task factory
# ──────────────────────────────────────────────
def make_extract_task(entity: str, dag: DAG) -> PythonOperator:
    """
    Creates one Airflow task per entity.
    We extract all 9 entities in parallel (they are independent).
    Each task calls run_extraction(entity) from our extractor module.
    """
    import sys
    sys.path.insert(0, "/opt/airflow/extractor")

    def _extract():
        from extractor import run_extraction
        run_extraction(entity=entity)

    return PythonOperator(
        task_id=f"extract_{entity}",
        python_callable=_extract,
        dag=dag,
    )


# ──────────────────────────────────────────────
# dlt load task
# ──────────────────────────────────────────────
def run_dlt_load():
    """Move data from lake → warehouse using dlt."""
    import sys
    sys.path.insert(0, "/opt/airflow/dlt_pipeline")
    from lake_to_warehouse import run_dlt_pipeline
    run_dlt_pipeline()


# ──────────────────────────────────────────────
# DAG definition
# ──────────────────────────────────────────────
with DAG(
    dag_id="retailco_master_pipeline",
    description="End-to-end RetailCo ERP data pipeline",
    default_args=DEFAULT_ARGS,
    schedule_interval="@daily",          # runs once per day at midnight
    catchup=True,                        # enables backfill for historical dates
    max_active_runs=1,                   # don't run two days simultaneously
    tags=["retailco", "production"],
) as dag:

    # ── Step 1: Extract all 9 entities (run in parallel) ──────────
    ENTITIES = [
        "customers", "products", "stores", "employees",
        "orders", "order_items", "payments",
        "inventory_movements", "payment_methods",
    ]

    extract_tasks = [make_extract_task(entity, dag) for entity in ENTITIES]

    # ── Step 2: Load lake → warehouse with dlt ────────────────────
    dlt_load = PythonOperator(
        task_id="dlt_load",
        python_callable=run_dlt_load,
    )

    # ── Step 3: Run SCD2 snapshots ────────────────────────────────
    # dbt snapshot captures changes in customers and products
    dbt_snapshot = PythonOperator(
        task_id="dbt_snapshot",
        python_callable=lambda: run_dbt("snapshot"),
    )

    # ── Step 4: Build staging models (views) ─────────────────────
    dbt_staging = PythonOperator(
        task_id="dbt_staging",
        python_callable=lambda: run_dbt("run --select staging"),
    )

    # ── Step 5: Build marts (dims + facts as tables) ─────────────
    dbt_marts = PythonOperator(
        task_id="dbt_marts",
        python_callable=lambda: run_dbt("run --select marts"),
    )

    # ── Step 6: Run all dbt tests ─────────────────────────────────
    # If any test fails, this task fails → pipeline halts
    dbt_test = PythonOperator(
        task_id="dbt_test",
        python_callable=lambda: run_dbt("test"),
    )

    # ──────────────────────────────────────────────────────────────
    # Wire up the dependencies (this defines the ORDER)
    # ──────────────────────────────────────────────────────────────
    # All 9 extract tasks → dlt_load (only after ALL extracts succeed)
    extract_tasks >> dlt_load

    # Sequential chain after load:
    dlt_load >> dbt_snapshot >> dbt_staging >> dbt_marts >> dbt_test
