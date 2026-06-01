-- models/staging/stg_order_items.sql
WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'order_items') }}),
typed AS (
    SELECT
        (raw_data->>'order_item_id')::TEXT          AS order_item_id,
        (raw_data->>'order_id')::TEXT               AS order_id,
        (raw_data->>'product_id')::TEXT             AS product_id,
        (raw_data->>'quantity')::INT                AS quantity,
        (raw_data->>'unit_price')::NUMERIC(12,2)    AS unit_price,
        (raw_data->>'discount_pct')::NUMERIC(5,4)   AS discount_pct,
        (raw_data->>'line_total')::NUMERIC(12,2)    AS line_total,
        (raw_data->>'updated_at')::TIMESTAMPTZ      AS updated_at,
        _extracted_at
    FROM source
)
SELECT * FROM typed
