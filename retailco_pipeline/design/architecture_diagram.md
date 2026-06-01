# RetailCo Data Platform — Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL SOURCE                                  │
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  RetailCo ERP REST API  (Heroku)                                 │  │
│   │  https://hngstage8da-55c7f5f769c8.herokuapp.com                  │  │
│   │  9 Entities: customers, products, stores, employees, orders,     │  │
│   │  order_items, payments, inventory_movements, payment_methods     │  │
│   └──────────────────────┬───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                           │ HTTPS  X-API-Key header
                           │ Cursor pagination + updated_after filter
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER (Docker)                          │
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Apache Airflow 2.9  (retailco_master_pipeline DAG)              │  │
│   │  ┌────────────────────────────────────────────────────────────┐  │  │
│   │  │  @daily schedule │ catchup=True │ retries=2 + backoff      │  │  │
│   │  └────────────────────────────────────────────────────────────┘  │  │
│   │                                                                  │  │
│   │  Task Graph:                                                     │  │
│   │  [extract_customers]─┐                                           │  │
│   │  [extract_products]──┤                                           │  │
│   │  [extract_stores]────┤                                           │  │
│   │  [extract_employees]─┤                                           │  │
│   │  [extract_orders]────┼──► [dlt_load] ──► [dbt_snapshot]        │  │
│   │  [extract_order_items┤                        │                  │  │
│   │  [extract_payments]──┤                   [dbt_staging]          │  │
│   │  [extract_inventory]─┤                        │                  │  │
│   │  [extract_pay_methods┘                   [dbt_marts]            │  │
│   │                                               │                  │  │
│   │                                          [dbt_test]              │  │
│   └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
        │                          │                        │
        ▼                          ▼                        ▼
┌───────────────┐      ┌───────────────────┐    ┌─────────────────────┐
│   EXTRACTION  │      │  LOAD (dlt)       │    │ TRANSFORM (dbt)     │
│               │      │                   │    │                     │
│  Python 3.11  │      │  dlt 0.4+         │    │  dbt-core 1.7+      │
│  extractor.py │      │  lake_to_         │    │  dbt-postgres       │
│               │      │  warehouse.py     │    │  dbt_utils          │
│  ✓ Retry/429  │      │                   │    │                     │
│  ✓ Watermarks │      │  ✓ Incremental    │    │  Snapshots (SCD2)   │
│  ✓ Upsert     │      │  ✓ Type coerce    │    │  Staging (views)    │
│  ✓ Pagination │      │  ✓ Idempotent     │    │  Marts (tables)     │
└───────┬───────┘      └────────┬──────────┘    └──────────┬──────────┘
        │                       │                           │
        ▼                       ▼                           ▼
┌───────────────────┐   ┌───────────────────┐   ┌──────────────────────┐
│   LAKE POSTGRES   │   │ WAREHOUSE POSTGRES │   │  WAREHOUSE POSTGRES  │
│   (port 5433)     │   │    raw schema      │   │   marts schema       │
│                   │   │   (port 5434)      │   │   (port 5434)        │
│  raw.customers    │   │                    │   │                      │
│  raw.products     │   │   raw.customers    │   │   dim_date           │
│  raw.orders       │   │   raw.products     │   │   dim_customer (SCD2)│
│  raw.order_items  │   │   raw.orders       │   │   dim_product  (SCD2)│
│  raw.payments     │   │   raw.payments     │   │   dim_store          │
│  raw.stores       │   │   ...              │   │   dim_employee       │
│  raw.employees    │   │                    │   │   dim_payment_method │
│  raw.inventory_   │   │                    │   │                      │
│    movements      │   │                    │   │   fct_sales          │
│  raw.pay_methods  │   │                    │   │   fct_payments       │
│  raw.watermarks   │   │                    │   │   fct_inventory_daily│
│                   │   │                    │   │   fct_order_lifecycle│
│  (JSONB storage)  │   │  (typed columns)   │   │   flagged_payments   │
└───────────────────┘   └───────────────────┘   └──────────────────────┘
```

## Container Layout (Docker Compose)

| Container          | Image                          | Purpose                          |
|--------------------|--------------------------------|----------------------------------|
| `airflow-db`       | postgres:15                    | Airflow's own metadata storage   |
| `airflow-webserver`| apache/airflow:2.9.2-python3.11| Airflow UI at localhost:8080     |
| `airflow-scheduler`| apache/airflow:2.9.2-python3.11| Runs DAGs on schedule            |
| `lake-db`          | postgres:15                    | Raw data lake (port 5433)        |
| `warehouse-db`     | postgres:15                    | Analytics warehouse (port 5434)  |

## Data Flow

```
ERP API → Python Extractor → Lake DB (raw.*)
                                  ↓
                            dlt Pipeline
                                  ↓
                         Warehouse raw.*
                                  ↓
                         dbt snapshot (SCD2)
                                  ↓
                         dbt staging (views)
                                  ↓
                         dbt marts (dim + fct tables)
                                  ↓
                         dbt tests (data quality gate)
```
