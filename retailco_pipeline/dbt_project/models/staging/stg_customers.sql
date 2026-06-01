-- models/staging/stg_customers.sql
-- ─────────────────────────────────────────────────────────────
-- Staging: Customers
-- What this does (plain English):
--   1. Reads raw customer JSONB from the warehouse raw schema.
--   2. Casts every field to the right data type.
--   3. Renames fields to snake_case consistency.
--   4. KEEPS soft-deleted customers (is_deleted = true) — they are
--      needed for SCD2 history. The dim_customer snapshot will
--      mark them is_current = false.
-- ─────────────────────────────────────────────────────────────

WITH source AS (
    SELECT
        raw_data,
        _extracted_at
    FROM {{ source('raw', 'customers') }}
),

typed AS (
    SELECT
        (raw_data->>'customer_id')::TEXT                            AS customer_id,
        (raw_data->>'first_name')::TEXT                            AS first_name,
        (raw_data->>'last_name')::TEXT                             AS last_name,
        (raw_data->>'email')::TEXT                                 AS email,
        (raw_data->>'phone')::TEXT                                 AS phone,
        (raw_data->>'address')::TEXT                               AS address,
        (raw_data->>'city')::TEXT                                  AS city,
        (raw_data->>'segment')::TEXT                               AS segment,
        (raw_data->>'is_deleted')::BOOLEAN                         AS is_deleted,
        (raw_data->>'effective_from')::TIMESTAMPTZ                 AS effective_from,
        (raw_data->>'updated_at')::TIMESTAMPTZ                     AS updated_at,
        (raw_data->>'created_at')::TIMESTAMPTZ                     AS created_at,
        _extracted_at
    FROM source
)

SELECT * FROM typed
