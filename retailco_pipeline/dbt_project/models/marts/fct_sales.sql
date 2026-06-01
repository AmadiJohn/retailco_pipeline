-- models/marts/fct_sales.sql
-- ─────────────────────────────────────────────────────────────
-- Fact: Sales (Transactional Grain — one row per order line item)
--
-- Plain English:
-- If Order #101 has 3 products, this table has 3 rows for that order.
-- Each row answers: who bought it, where, when, what, how much.
--
-- All foreign keys are SURROGATE keys (not natural keys from API).
-- This is the Kimball rule: facts reference dimension surrogate keys.
--
-- SCD2 join logic: we match the customer/product SK that was current
-- at the time of the order_date. This ensures if a customer changed
-- segments after the purchase, we still see the right segment.
-- ─────────────────────────────────────────────────────────────

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    WHERE is_deleted = FALSE              -- exclude cancelled orders from revenue
),

items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

-- Join orders to items to get one row per order line
order_lines AS (
    SELECT
        i.order_item_id,
        i.order_id,
        o.customer_id,
        o.store_id,
        o.employee_id,
        i.product_id,
        o.order_date,
        i.quantity,
        i.unit_price,
        i.discount_pct,
        i.line_total,
        o.status                            AS order_status
    FROM items i
    JOIN orders o USING (order_id)
),

-- Resolve surrogate keys from dimensions
-- For SCD2 dims: join on natural key AND date falls within valid window
dim_customer AS (SELECT * FROM {{ ref('dim_customer') }}),
dim_product  AS (SELECT * FROM {{ ref('dim_product') }}),
dim_store    AS (SELECT * FROM {{ ref('dim_store') }}),
dim_employee AS (SELECT * FROM {{ ref('dim_employee') }}),
dim_date     AS (SELECT * FROM {{ ref('dim_date') }})

SELECT
    -- Surrogate key for this fact row
    {{ dbt_utils.generate_surrogate_key(['ol.order_item_id']) }}    AS sales_sk,

    -- Dimension foreign keys (surrogate)
    dc.customer_sk,
    dp.product_sk,
    ds.store_sk,
    de.employee_sk,
    dd.date_key                                                      AS order_date_key,

    -- Natural keys (for debugging only — do NOT use in reports)
    ol.order_id,
    ol.order_item_id,

    -- Measures (additive — you can SUM these)
    ol.quantity,
    ol.unit_price,
    ol.discount_pct,
    ROUND(ol.unit_price * ol.discount_pct, 2)                        AS discount_amount,
    ol.line_total                                                    AS revenue,
    ol.line_total - (dp.cost_price * ol.quantity)                   AS gross_profit,

    ol.order_status

FROM order_lines ol

-- SCD2 customer join: find the customer version active at order time
LEFT JOIN dim_customer dc
    ON ol.customer_id = dc.customer_id
    AND ol.order_date >= dc.valid_from
    AND (dc.valid_to IS NULL OR ol.order_date < dc.valid_to)

-- SCD2 product join: find the product version active at order time
LEFT JOIN dim_product dp
    ON ol.product_id = dp.product_id
    AND ol.order_date >= dp.valid_from
    AND (dp.valid_to IS NULL OR ol.order_date < dp.valid_to)

LEFT JOIN dim_store    ds ON ol.store_id    = ds.store_id
LEFT JOIN dim_employee de ON ol.employee_id = de.employee_id
LEFT JOIN dim_date     dd ON ol.order_date::DATE = dd.calendar_date
