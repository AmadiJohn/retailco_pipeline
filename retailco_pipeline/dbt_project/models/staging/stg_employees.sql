-- models/staging/stg_employees.sql
WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'employees') }}),
typed AS (
    SELECT
        (raw_data->>'employee_id')::TEXT        AS employee_id,
        (raw_data->>'first_name')::TEXT         AS first_name,
        (raw_data->>'last_name')::TEXT          AS last_name,
        (raw_data->>'email')::TEXT              AS email,
        (raw_data->>'role')::TEXT               AS role,
        (raw_data->>'store_id')::TEXT           AS store_id,
        (raw_data->>'hire_date')::DATE          AS hire_date,
        (raw_data->>'is_deleted')::BOOLEAN      AS is_deleted,
        (raw_data->>'updated_at')::TIMESTAMPTZ  AS updated_at,
        _extracted_at
    FROM source
)
SELECT * FROM typed
