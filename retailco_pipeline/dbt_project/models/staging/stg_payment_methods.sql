-- models/staging/stg_payment_methods.sql
WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'payment_methods') }}),
typed AS (
    SELECT
        (raw_data->>'payment_method_id')::TEXT  AS payment_method_id,
        (raw_data->>'method_name')::TEXT        AS method_name,
        (raw_data->>'provider')::TEXT           AS provider,
        (raw_data->>'is_digital')::BOOLEAN      AS is_digital,
        (raw_data->>'updated_at')::TIMESTAMPTZ  AS updated_at,
        _extracted_at
    FROM source
)
SELECT * FROM typed
