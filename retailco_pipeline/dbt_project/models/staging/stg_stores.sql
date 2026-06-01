-- models/staging/stg_stores.sql
WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'stores') }}),
typed AS (
    SELECT
        (raw_data->>'store_id')::TEXT           AS store_id,
        (raw_data->>'store_name')::TEXT         AS store_name,
        (raw_data->>'city')::TEXT               AS city,
        (raw_data->>'region')::TEXT             AS region,
        (raw_data->>'address')::TEXT            AS address,
        (raw_data->>'manager_id')::TEXT         AS manager_id,
        (raw_data->>'opened_date')::DATE        AS opened_date,
        (raw_data->>'updated_at')::TIMESTAMPTZ  AS updated_at,
        _extracted_at
    FROM source
)
SELECT * FROM typed
