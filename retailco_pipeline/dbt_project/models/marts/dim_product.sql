-- models/marts/dim_product.sql
-- SCD2 Product Dimension (price & category changes tracked)

WITH snapshot AS (
    SELECT * FROM {{ ref('snap_products') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['product_id', 'dbt_updated_at']) }}
                                        AS product_sk,
    product_id,
    product_name,
    sku,
    category,
    unit_price,
    cost_price,
    unit_price - cost_price             AS gross_margin,
    CASE WHEN cost_price > 0
         THEN ROUND((unit_price - cost_price) / cost_price * 100, 2)
         ELSE NULL END                  AS margin_pct,
    supplier,
    is_deleted,
    dbt_valid_from                      AS valid_from,
    dbt_valid_to                        AS valid_to,
    CASE WHEN dbt_valid_to IS NULL
         THEN TRUE ELSE FALSE END       AS is_current
FROM snapshot
