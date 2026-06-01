-- models/marts/fct_order_lifecycle.sql
-- ─────────────────────────────────────────────────────────────
-- Fact: Order Lifecycle (Accumulating Snapshot — one row per order)
--
-- Plain English:
-- An accumulating snapshot tracks an order's JOURNEY through stages:
-- pending → paid → shipped → delivered.
-- Each order gets ONE row. As the order progresses, we UPDATE that row
-- by filling in the timestamp for each milestone.
-- This lets us answer: "How long does it take from order to delivery?"
-- 
-- Late-arriving data (the task's quirk) is handled here because
-- when orders.status updates, dbt re-runs and picks up the new timestamps.
-- Since this is a TABLE materialization, it's always rebuilt fresh.
-- ─────────────────────────────────────────────────────────────

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

dim_customer AS (SELECT * FROM {{ ref('dim_customer') }} WHERE is_current = TRUE),
dim_store    AS (SELECT * FROM {{ ref('dim_store') }}),
dim_date     AS (SELECT * FROM {{ ref('dim_date') }})

SELECT
    {{ dbt_utils.generate_surrogate_key(['o.order_id']) }}           AS lifecycle_sk,

    -- Dimension FKs
    dc.customer_sk,
    ds.store_sk,
    dd_order.date_key                                                AS order_date_key,
    dd_paid.date_key                                                 AS paid_date_key,
    dd_shipped.date_key                                              AS shipped_date_key,
    dd_delivered.date_key                                            AS delivered_date_key,

    -- Natural key
    o.order_id,

    -- Status timestamps (NULLs = milestone not yet reached)
    o.order_date                                                     AS ordered_at,
    o.pending_at,
    o.paid_at,
    o.shipped_at,
    o.delivered_at,

    -- Current status
    o.status,
    o.is_deleted                                                     AS is_cancelled,

    -- Derived lag metrics (how long between each stage, in hours)
    ROUND(EXTRACT(EPOCH FROM (o.paid_at      - o.order_date)) / 3600, 1)   AS hours_to_payment,
    ROUND(EXTRACT(EPOCH FROM (o.shipped_at   - o.paid_at))    / 3600, 1)   AS hours_to_shipment,
    ROUND(EXTRACT(EPOCH FROM (o.delivered_at - o.shipped_at)) / 3600, 1)   AS hours_to_delivery,
    ROUND(EXTRACT(EPOCH FROM (o.delivered_at - o.order_date)) / 3600, 1)   AS total_hours_to_delivery,

    -- Order value
    o.total_amount,
    o.discount_amount

FROM orders o

LEFT JOIN dim_customer dc
    ON o.customer_id = dc.customer_id

LEFT JOIN dim_store ds
    ON o.store_id = ds.store_id

-- Date dimension joins for each milestone
LEFT JOIN dim_date dd_order     ON o.order_date::DATE     = dd_order.calendar_date
LEFT JOIN dim_date dd_paid      ON o.paid_at::DATE        = dd_paid.calendar_date
LEFT JOIN dim_date dd_shipped   ON o.shipped_at::DATE     = dd_shipped.calendar_date
LEFT JOIN dim_date dd_delivered ON o.delivered_at::DATE   = dd_delivered.calendar_date
