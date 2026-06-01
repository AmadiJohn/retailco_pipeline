-- models/marts/dim_store.sql
-- Store Dimension (no SCD2 needed — stores don't move)

WITH stg AS (SELECT * FROM {{ ref('stg_stores') }})

SELECT
    {{ dbt_utils.generate_surrogate_key(['store_id']) }}  AS store_sk,
    store_id,
    store_name,
    city,
    region,
    address,
    manager_id,
    opened_date
FROM stg
