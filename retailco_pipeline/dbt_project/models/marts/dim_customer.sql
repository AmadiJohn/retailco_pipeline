-- models/marts/dim_customer.sql
-- ─────────────────────────────────────────────────────────────
-- Dimension: Customer (SCD Type 2)
--
-- Plain English:
-- Reads from the snap_customers snapshot (which already handles
-- history). We add a surrogate key (a hash of customer_id + valid_from)
-- so fact tables always join on a unique key — even when the same
-- customer has multiple historical rows.
--
-- Fact tables join: fct_sales.customer_sk → dim_customer.customer_sk
-- WHERE the order_date falls between valid_from and valid_to.
-- ─────────────────────────────────────────────────────────────

WITH snapshot AS (
    SELECT * FROM {{ ref('snap_customers') }}
)

SELECT
    -- Surrogate key: hash of natural key + version timestamp
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_updated_at']) }}
                                            AS customer_sk,

    -- Natural key (keep for debugging)
    customer_id,

    -- Customer attributes
    first_name,
    last_name,
    first_name || ' ' || last_name          AS full_name,
    email,
    phone,
    address,
    city,
    segment,

    -- Soft delete flag
    is_deleted,

    -- SCD2 validity window (added automatically by dbt snapshot)
    dbt_valid_from                          AS valid_from,
    dbt_valid_to                            AS valid_to,
    CASE WHEN dbt_valid_to IS NULL
         THEN TRUE ELSE FALSE END           AS is_current

FROM snapshot
