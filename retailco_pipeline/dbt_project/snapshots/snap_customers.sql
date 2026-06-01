-- snapshots/snap_customers.sql
-- ─────────────────────────────────────────────────────────────
-- SCD Type 2 Snapshot: Customers
--
-- What SCD2 means (plain English):
-- When a customer changes their address or segment, we don't overwrite
-- the old record. Instead, we ADD a new row and mark the old one as
-- "no longer current". This lets us answer: "What segment was this
-- customer in when they made this purchase in January?"
--
-- dbt snapshots do this automatically by comparing the updated_at
-- timestamp. When it changes, dbt closes the old row (sets valid_to)
-- and opens a new one (sets valid_from = now, valid_to = null, is_current = true).
-- ─────────────────────────────────────────────────────────────

{% snapshot snap_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=False,  -- soft deletes stay as history
    )
}}

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    address,
    city,
    segment,
    is_deleted,
    effective_from,
    updated_at,
    created_at
FROM {{ ref('stg_customers') }}

{% endsnapshot %}
