-- models/staging/stg_orders.sql
-- Excludes soft-deleted (cancelled) orders from fact tables.
-- They are kept in staging but filtered downstream.

WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'orders') }}),
typed AS (
    SELECT
        (raw_data->>'order_id')::TEXT               AS order_id,
        (raw_data->>'customer_id')::TEXT            AS customer_id,
        (raw_data->>'store_id')::TEXT               AS store_id,
        (raw_data->>'employee_id')::TEXT            AS employee_id,
        (raw_data->>'order_date')::TIMESTAMPTZ      AS order_date,
        (raw_data->>'status')::TEXT                 AS status,
        (raw_data->>'total_amount')::NUMERIC(12,2)  AS total_amount,
        (raw_data->>'discount_amount')::NUMERIC(12,2) AS discount_amount,
        (raw_data->>'is_deleted')::BOOLEAN          AS is_deleted,
        (raw_data->>'pending_at')::TIMESTAMPTZ      AS pending_at,
        (raw_data->>'paid_at')::TIMESTAMPTZ         AS paid_at,
        (raw_data->>'shipped_at')::TIMESTAMPTZ      AS shipped_at,
        (raw_data->>'delivered_at')::TIMESTAMPTZ    AS delivered_at,
        (raw_data->>'updated_at')::TIMESTAMPTZ      AS updated_at,
        _extracted_at
    FROM source
)
SELECT * FROM typed
