-- models/staging/stg_inventory_movements.sql
WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'inventory_movements') }}),
typed AS (
    SELECT
        (raw_data->>'movement_id')::TEXT            AS movement_id,
        (raw_data->>'product_id')::TEXT             AS product_id,
        (raw_data->>'store_id')::TEXT               AS store_id,
        (raw_data->>'movement_type')::TEXT          AS movement_type,  -- IN / OUT / ADJUSTMENT
        (raw_data->>'quantity')::INT                AS quantity,
        (raw_data->>'movement_date')::DATE          AS movement_date,
        (raw_data->>'reference_id')::TEXT           AS reference_id,
        (raw_data->>'updated_at')::TIMESTAMPTZ      AS updated_at,
        _extracted_at
    FROM source
)
SELECT * FROM typed
