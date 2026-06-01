"""
RetailCo ERP Extractor

Pulls all 9 entities from the ERP REST API into the Lake Postgres database (raw schema).

How it works (plain English):
1. For each entity (customers, products, orders, etc.), check the watermark table
   to find the last time we successfully extracted data.
2. Send a request to the API asking only for rows updated AFTER that timestamp
   (incremental loading — not downloading everything every time).
3. If it's the very first run, the watermark is 1970, so we get everything (full extract).
4. Handle pagination: the API returns pages of data with a cursor. We keep fetching
   pages until the API says "no more pages".
5. Handle failures: if the API returns 429 (rate limit) or 500 (server error),
   we wait and retry up to 5 times with exponential backoff.
6. Write rows to PostgreSQL using upsert (INSERT ... ON CONFLICT DO UPDATE)
   so running the same DAG twice doesn't create duplicate rows.
7. Update the watermark so next run only fetches new data.
"""

import os
import time
import logging
import psycopg2
import psycopg2.extras
import requests
import hashlib
import json
from datetime import datetime, timezone
from typing import Optional

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)


# Configuration (read from environment variables)

ERP_BASE_URL = os.environ["ERP_BASE_URL"]
ERP_API_KEY  = os.environ["ERP_API_KEY"]

LAKE_CONN = {
    "host":     os.environ["LAKE_DB_HOST"],
    "port":     int(os.environ.get("LAKE_DB_PORT", 5432)),
    "dbname":   os.environ["LAKE_DB_NAME"],
    "user":     os.environ["LAKE_DB_USER"],
    "password": os.environ["LAKE_DB_PASSWORD"],
}

# All 9 ERP entities and the column that is their primary key
ENTITIES = {
    "customers":           "id",
    "products":            "product_id",
    "stores":              "store_id",
    "employees":           "employee_id",
    "orders":              "order_id",
    "order_items":         "order_item_id",
    "payments":            "payment_id",
    "inventory_movements": "movement_id",
    "payment_methods":     "payment_method_id",
}

MAX_RETRIES        = 5
INITIAL_BACKOFF_S  = 2   # seconds to wait on first retry
PAGE_LIMIT         = 500 # rows per API page



# HTTP helpers


def _get_session() -> requests.Session:
    """Create a requests Session with the API key header pre-set."""
    session = requests.Session()
    session.headers.update({
        "X-API-Key": ERP_API_KEY,
        "Content-Type": "application/json",
    })
    return session


def _fetch_with_retry(session: requests.Session, url: str, params: dict) -> dict:
    """
    Fetch a single URL, retrying on 429 (rate limit) or 500 (server error).
    Uses exponential backoff: wait 2s, then 4s, then 8s, then 16s, then 32s.
    If all 5 attempts fail, raises an exception (Airflow will retry the task).
    """
    backoff = INITIAL_BACKOFF_S

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = session.get(url, params=params, timeout=30)

            if response.status_code == 200:
                return response.json()

            elif response.status_code == 429:
                # Rate limited. The API tells us how long to wait.
                retry_after = int(response.headers.get("Retry-After", backoff))
                log.warning(f"Rate limited. Waiting {retry_after}s (attempt {attempt}/{MAX_RETRIES})")
                time.sleep(retry_after)

            elif response.status_code in (500, 502, 503, 504):
                log.warning(f"Server error {response.status_code}. Retrying in {backoff}s (attempt {attempt}/{MAX_RETRIES})")
                time.sleep(backoff)
                backoff *= 2  # double the wait time each attempt

            else:
                response.raise_for_status()  # 400, 401, 404 etc — don't retry these

        except requests.exceptions.Timeout:
            log.warning(f"Request timed out. Retrying in {backoff}s (attempt {attempt}/{MAX_RETRIES})")
            time.sleep(backoff)
            backoff *= 2

    raise RuntimeError(f"Failed to fetch {url} after {MAX_RETRIES} attempts")


def _build_entity_urls(entity: str) -> tuple[str, str]:
    """Return the direct and versioned ERP endpoints for an entity."""
    base_url = ERP_BASE_URL.rstrip("/")
    return f"{base_url}/{entity}", f"{base_url}/api/v1/{entity}"



# Watermark helpers

def get_watermark(conn, entity: str) -> str:
    """Read the last successful extract timestamp for an entity."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT last_updated FROM raw.watermarks WHERE entity_name = %s",
            (entity,)
        )
        row = cur.fetchone()
        if row:
            return row[0].isoformat()
        return "1970-01-01T00:00:00+00:00"


def set_watermark(conn, entity: str, timestamp: str):
    """Update the watermark after a successful extract."""
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO raw.watermarks (entity_name, last_updated, updated_at)
            VALUES (%s, %s, NOW())
            ON CONFLICT (entity_name) DO UPDATE
              SET last_updated = EXCLUDED.last_updated,
                  updated_at   = EXCLUDED.updated_at
            """,
            (entity, timestamp)
        )
    conn.commit()
    log.info(f"Watermark updated for '{entity}' → {timestamp}")



# Table creation (auto-creates raw.table if missing)


def ensure_table_exists(conn, entity: str, sample_row: dict):
    """
    Dynamically create a raw table if it doesn't exist yet.
    We use JSONB for all columns except the primary key and updated_at —
    this avoids schema mismatches when the API changes its response shape.
    The _extracted_at column records when WE pulled the data.
    """
    pk_col = ENTITIES[entity]
    try:
        with conn.cursor() as cur:
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS raw.{entity} (
                    {pk_col}        TEXT        PRIMARY KEY,
                    raw_data        JSONB       NOT NULL,
                    updated_at      TIMESTAMPTZ,
                    _extracted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
            """)
        conn.commit()
    except psycopg2.errors.InsufficientPrivilege as exc:
        raise RuntimeError(
            "The configured lake DB user does not have permission to create or modify tables in schema 'raw'. "
            "Please initialize the lake database schema using create_table.sql or docker/lake_init.sql, "
            "and ensure the lake user has USAGE on schema raw plus SELECT/INSERT/UPDATE/DELETE on raw tables."
        ) from exc

    log.info(f"Table raw.{entity} is ready")



# Upsert rows into lake


def upsert_rows(conn, entity: str, rows: list[dict]):
    """
    Write rows to the lake using UPSERT (INSERT ... ON CONFLICT DO UPDATE).
    This means if we run the same extraction twice, we just overwrite — no duplicates.
    We store the entire API row as JSONB so we don't lose any fields.
    Deduplicates rows within the same batch by primary key (keeps the last occurrence).
    """
    if not rows:
        return

    pk_col = ENTITIES[entity]

    # Find the actual primary key column name in the database for raw.<entity>.
    with conn.cursor() as cur:
        try:
            cur.execute(
                """
                SELECT a.attname
                FROM pg_index i
                JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                WHERE i.indrelid = %s::regclass AND i.indisprimary
                """,
                (f"raw.{entity}",)
            )
            row = cur.fetchone()
            db_pk_col = row[0] if row else pk_col
        except Exception:
            # If the query fails for any reason, fall back to the expected mapping
            db_pk_col = pk_col

    # Deduplicate by primary key (using API fields as candidates) keeping the last occurrence
    # If no candidate PK is present, build a deterministic hash of the JSON payload
    seen = {}
    for r in rows:
        # Try the expected pk field first, then common alternatives ('id', or drop '_id')
        candidates = [pk_col, "id"]
        if pk_col.endswith("_id"):
            candidates.append(pk_col.replace("_id", ""))

        pk_value = ""
        for c in candidates:
            val = r.get(c)
            if val is not None and val != "":
                pk_value = str(val)
                break

        # If still no PK found, use a deterministic SHA256 of the JSON payload
        if not pk_value:
            try:
                dump = json.dumps(r, sort_keys=True, ensure_ascii=False)
            except Exception:
                dump = str(r)
            pk_value = hashlib.sha256(dump.encode("utf-8")).hexdigest()

        updated_at = r.get("updated_at")
        seen[pk_value] = (pk_value, psycopg2.extras.Json(r), updated_at)

    records = list(seen.values())

    with conn.cursor() as cur:
        psycopg2.extras.execute_values(
            cur,
            f"""
            INSERT INTO raw.{entity} ({db_pk_col}, raw_data, updated_at, _extracted_at)
            VALUES %s
            ON CONFLICT ({db_pk_col}) DO UPDATE
              SET raw_data      = EXCLUDED.raw_data,
                  updated_at    = EXCLUDED.updated_at,
                  _extracted_at = EXCLUDED._extracted_at
            """,
            [(pk, data, upd, datetime.now(timezone.utc)) for pk, data, upd in records],
            template="(%s, %s, %s, %s)"
        )
    conn.commit()
    log.info(f"  Upserted {len(records)} rows into raw.{entity}")



# Main extraction logic


def extract_entity(entity: str, watermark: str, session: requests.Session, conn):
    """
    Extract all pages for one entity from the ERP API.

    The API uses cursor pagination:
    - First request: GET /{entity}?updated_after=<ts>&limit=500
    - Response includes: { data: [...], has_more: true/false, next_cursor: "abc" }
    - If has_more is true, fetch next page: GET /{entity}?cursor=abc&limit=500
    - Keep going until has_more is false
    """
    direct_url, versioned_url = _build_entity_urls(entity)
    url           = direct_url
    total_fetched = 0
    cursor        = None
    is_first_page = True
    max_updated   = watermark  # track the newest timestamp in this batch

    log.info(f"Extracting '{entity}' (updated_after={watermark})")

    while True:
        params = {"limit": PAGE_LIMIT}

        if cursor:
            # Subsequent pages: just pass the cursor (not updated_after)
            params["cursor"] = cursor
        else:
            # First page: pass the incremental filter
            params["updated_after"] = watermark

        try:
            response_json = _fetch_with_retry(session, url, params)
        except requests.exceptions.HTTPError as exc:
            if exc.response is not None and exc.response.status_code == 404 and url == direct_url:
                log.warning(
                    "Primary endpoint %s returned 404. Retrying with fallback endpoint %s",
                    direct_url,
                    versioned_url,
                )
                url = versioned_url
                response_json = _fetch_with_retry(session, url, params)
            else:
                raise

        rows     = response_json.get("data", [])
        has_more = response_json.get("has_more", False)
        cursor   = response_json.get("next_cursor")

        if rows and is_first_page:
            ensure_table_exists(conn, entity, rows[0])
            is_first_page = False

        if rows:
            upsert_rows(conn, entity, rows)
            total_fetched += len(rows)

            # Track the maximum updated_at in this batch for the watermark
            for row in rows:
                row_updated = row.get("updated_at", "")
                if row_updated and row_updated > max_updated:
                    max_updated = row_updated

        log.info(f"  Page done. has_more={has_more}, rows_this_page={len(rows)}")

        if not has_more:
            break

    log.info(f"Finished '{entity}': {total_fetched} total rows extracted")
    return max_updated



# Entry point (called by Airflow DAG)


def run_extraction(entity: Optional[str] = None):
    """
    Main function. If entity is specified, extract only that one.
    Otherwise extract all 9 entities in order.
    Called by the Airflow DAG.
    """
    session = _get_session()

    with psycopg2.connect(**LAKE_CONN) as conn:
        entities_to_run = [entity] if entity else list(ENTITIES.keys())

        for ent in entities_to_run:
            watermark    = get_watermark(conn, ent)
            new_watermark = extract_entity(ent, watermark, session, conn)

            # Only update watermark if we actually fetched something new
            if new_watermark > watermark:
                set_watermark(conn, ent, new_watermark)
            else:
                log.info(f"No new data for '{ent}', watermark unchanged")

    log.info("Extraction complete for all entities!")


if __name__ == "__main__":
    # You can run this directly for testing: python extractor.py
    run_extraction()
