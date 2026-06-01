# RetailCo Modern Data Pipeline
**HNG Internship Stage 8 - Team C**

A production-grade end-to-end data pipeline built with Apache Airflow, Python, dlt, dbt, and PostgreSQL all running in Docker.

---

## What This Pipeline Does

1. **Extracts** data from the RetailCo ERP REST API (9 entities)
2. **Stores** raw data in a PostgreSQL data lake
3. **Loads** lake data into a warehouse using dlt (incremental)
4. **Transforms** warehouse data into Kimball dimensional models using dbt
5. **Orchestrates** everything on a daily schedule with Airflow

---

## Prerequisites

Install these on your machine before starting:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes Docker Compose)
- Git

That's it. Everything else (Python, Airflow, dbt, PostgreSQL) runs inside Docker.

---

## Setup - Step by Step

### Step 1: Clone the Repository
```bash
git clone https://github.com/YOUR_TEAM/retailco-pipeline.git
cd retailco-pipeline
```

### Step 2: Generate a Fernet Key (Airflow security requirement)
```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
Copy the output. Open `docker-compose.yml` and replace `your-fernet-key-here-generate-with-python-cryptography` with it.

### Step 3: Start Everything
```bash
docker compose up -d
```
This starts 5 containers:
- `airflow-webserver` - the Airflow UI
- `airflow-scheduler` - runs DAGs on schedule
- `airflow-db` - Airflow's own metadata database
- `lake-db` - raw data lake PostgreSQL
- `warehouse-db` - analytics warehouse PostgreSQL

Wait ~60 seconds for everything to initialise.

### Step 4: Initialise Airflow (first time only)
```bash
docker compose run --rm airflow-init
```
This creates the database tables and the admin user.

### Step 5: Install Python dependencies in Airflow
```bash
docker compose exec airflow-scheduler pip install -r /opt/airflow/extractor/requirements.txt
docker compose exec airflow-scheduler pip install -r /opt/airflow/dlt_pipeline/requirements.txt
docker compose exec airflow-scheduler pip install dbt-core dbt-postgres dbt-utils
```

### Step 6: Install dbt packages
```bash
docker compose exec airflow-scheduler bash -c "cd /opt/airflow/dbt_project && dbt deps --profiles-dir ."
```

---

## Running the Pipeline

### Open the Airflow UI
Go to: **http://localhost:8080**
Login: `admin` / `admin`

### Trigger a Manual Run
1. Click the **retailco_master_pipeline** DAG
2. Click the **Trigger DAG** button
3. Watch the task graph, each box turns green when it succeeds

### Run for a Specific Past Date (Backfill)
```bash
docker compose exec airflow-scheduler airflow dags backfill \
    --start-date 2024-01-01 \
    --end-date 2024-01-07 \
    retailco_master_pipeline
```

---

## Querying the Warehouse

Connect to the warehouse database:
```bash
docker compose exec warehouse-db psql -U wh_user -d warehouse
```

Or use any SQL client (DBeaver, TablePlus, etc.) with:
- **Host:** localhost
- **Port:** 5434
- **Database:** warehouse
- **User:** wh_user
- **Password:** wh_pass

### Sample Queries

**Revenue by store (last 30 days):**
```sql
SELECT
    s.store_name,
    s.city,
    SUM(f.revenue)      AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM marts.fct_sales f
JOIN marts.dim_store s  ON f.store_sk = s.store_sk
JOIN marts.dim_date  d  ON f.order_date_key = d.date_key
WHERE d.calendar_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY s.store_name, s.city
ORDER BY total_revenue DESC;
```

**Customer segment breakdown:**
```sql
SELECT
    c.segment,
    COUNT(DISTINCT c.customer_id) AS customers,
    SUM(f.revenue)                AS total_revenue,
    ROUND(AVG(f.revenue), 2)     AS avg_order_value
FROM marts.fct_sales f
JOIN marts.dim_customer c ON f.customer_sk = c.customer_sk
WHERE c.is_current = TRUE
GROUP BY c.segment
ORDER BY total_revenue DESC;
```

**Payment method usage:**
```sql
SELECT
    pm.method_name,
    COUNT(*)                AS payment_count,
    SUM(p.amount_paid)      AS total_amount,
    SUM(CASE WHEN p.is_refund THEN 1 ELSE 0 END) AS refund_count
FROM marts.fct_payments p
JOIN marts.dim_payment_method pm ON p.payment_method_sk = pm.payment_method_sk
GROUP BY pm.method_name
ORDER BY total_amount DESC;
```

**Anomalous payments:**
```sql
SELECT anomaly_type, COUNT(*), SUM(amount_paid)
FROM marts.flagged_payments
GROUP BY anomaly_type;
```

---

## Project Structure

```
retailco_pipeline/
├── docker-compose.yml          # Starts all services
├── docker/
│   ├── lake_init.sql           # Creates lake schema + watermarks table
│   └── warehouse_init.sql      # Creates warehouse schemas
│
├── extractor/
│   ├── extractor.py            # ERP API extractor (handles pagination, retries, watermarks)
│   └── requirements.txt
│
├── dlt_pipeline/
│   ├── lake_to_warehouse.py    # dlt incremental load
│   └── requirements.txt
│
├── dbt_project/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── packages.yml
│   ├── models/
│   │   ├── staging/            # stg_* views (type casting + renaming)
│   │   └── marts/              # dim_* and fct_* tables
│   ├── snapshots/              # SCD2 snapshots for customers + products
│   └── tests/                  # Custom data quality tests
│
├── airflow/
│   └── dags/
│       └── retailco_pipeline.py  # Master Airflow DAG
│
└── design/
    ├── bus_matrix.md
    ├── warehouse_erd.md
    └── architecture_diagram.md
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Airflow UI not loading | Wait 60s, then check `docker compose logs airflow-webserver` |
| Task fails with 429 | The extractor handles this automatically with backoff |
| dbt test fails | Check `docker compose exec airflow-scheduler dbt test --profiles-dir /opt/airflow/dbt_project` |
| Lake DB not accessible | Check `docker compose ps` - lake-db should be "healthy" |
