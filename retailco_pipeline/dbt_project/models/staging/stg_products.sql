-- models/staging/stg_products.sql
-- Staging: Products
-- Same pattern as customers. Keeps soft-deleted products for SCD2 history.

WITH source AS (
    SELECT raw_data, _extracted_at
    FROM {{ source('raw', 'products') }}
),

typed AS (
    SELECT
        (raw_data->>'product_id')::TEXT         AS product_id,
        (raw_data->>'product_name')::TEXT       AS product_name,
        (raw_data->>'sku')::TEXT                AS sku,
        (raw_data->>'category')::TEXT           AS category,
        (raw_data->>'unit_price')::NUMERIC(12,2) AS unit_price,
        (raw_data->>'cost_price')::NUMERIC(12,2) AS cost_price,
        (raw_data->>'supplier')::TEXT           AS supplier,
        (raw_data->>'is_deleted')::BOOLEAN      AS is_deleted,
        (raw_data->>'effective_from')::TIMESTAMPTZ AS effective_from,
        (raw_data->>'updated_at')::TIMESTAMPTZ  AS updated_at,
        (raw_data->>'created_at')::TIMESTAMPTZ  AS created_at,
        _extracted_at
    FROM source
)

SELECT * FROM typed
