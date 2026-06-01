{% snapshot snap_customers %}
{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=False
    )
}}
select
    customer_id, first_name, last_name,
    email, phone, segment, tier,
    address, city, state, is_deleted,
    effective_from, registered_at,
    created_at, updated_at
from {{ ref('stg_customers') }}
{% endsnapshot %}