-- models/marts/dim_payment_method.sql

WITH stg AS (SELECT * FROM {{ ref('stg_payment_methods') }})

SELECT
    {{ dbt_utils.generate_surrogate_key(['payment_method_id']) }} AS payment_method_sk,
    payment_method_id,
    method_name,
    provider,
    is_digital
FROM stg
