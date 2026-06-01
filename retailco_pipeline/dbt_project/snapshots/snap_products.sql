-- snapshots/snap_products.sql
-- SCD2 Snapshot: Products
-- Tracks when unit_price or category changes over time.

{% snapshot snap_products %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=False,
    )
}}

SELECT
    product_id,
    product_name,
    sku,
    category,
    unit_price,
    cost_price,
    supplier,
    is_deleted,
    effective_from,
    updated_at,
    created_at
FROM {{ ref('stg_products') }}

{% endsnapshot %}
