{% snapshot snap_products %}
{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=False
    )
}}
select
    product_id, sku, product_name,
    category, sub_category, brand,
    supplier, cost_price, selling_price,
    is_deleted, effective_from,
    created_at, updated_at
from {{ ref('stg_products') }}
{% endsnapshot %}