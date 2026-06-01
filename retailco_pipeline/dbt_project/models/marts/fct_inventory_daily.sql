-- models/marts/fct_inventory_daily.sql
-- ─────────────────────────────────────────────────────────────
-- Fact: Inventory Daily (Periodic Snapshot — one row per product × store × day)
--
-- Plain English:
-- We have raw inventory_movements (individual IN/OUT events).
-- We need to know: "How many units of Product X are in Store Y at end of each day?"
-- 
-- Steps:
-- 1. Sum all movements up to each day per product × store (running balance).
-- 2. Use a date spine to fill gaps (if no movement on Tuesday, carry forward Monday's balance).
-- 3. Join dimension surrogate keys.
-- ─────────────────────────────────────────────────────────────

WITH movements AS (
    SELECT * FROM {{ ref('stg_inventory_movements') }}
),

-- Get all product × store combinations that have ever had any movement
product_store_combos AS (
    SELECT DISTINCT product_id, store_id
    FROM movements
),

-- Date spine: one row per day in our range
date_spine AS (
    SELECT calendar_date FROM {{ ref('dim_date') }}
),

-- Cross join: every combo × every day (so we can fill gaps)
grid AS (
    SELECT
        psc.product_id,
        psc.store_id,
        ds.calendar_date
    FROM product_store_combos psc
    CROSS JOIN date_spine ds
),

-- Daily movement totals: net units moved per product × store × day
daily_movements AS (
    SELECT
        product_id,
        store_id,
        movement_date,
        SUM(CASE
            WHEN movement_type = 'IN'         THEN quantity
            WHEN movement_type = 'OUT'        THEN -quantity
            WHEN movement_type = 'ADJUSTMENT' THEN quantity  -- can be +/-
            ELSE 0
        END) AS net_units_moved
    FROM movements
    GROUP BY product_id, store_id, movement_date
),

-- Join grid to movements, compute running balance using window function
with_balance AS (
    SELECT
        g.product_id,
        g.store_id,
        g.calendar_date,
        COALESCE(dm.net_units_moved, 0)     AS units_moved_today,
        SUM(COALESCE(dm.net_units_moved, 0))
            OVER (
                PARTITION BY g.product_id, g.store_id
                ORDER BY g.calendar_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            )                               AS closing_stock_units
    FROM grid g
    LEFT JOIN daily_movements dm
        ON g.product_id = dm.product_id
        AND g.store_id  = dm.store_id
        AND g.calendar_date = dm.movement_date
),

dim_product AS (SELECT * FROM {{ ref('dim_product') }} WHERE is_current = TRUE),
dim_store   AS (SELECT * FROM {{ ref('dim_store') }}),
dim_date    AS (SELECT * FROM {{ ref('dim_date') }})

SELECT
    {{ dbt_utils.generate_surrogate_key(['wb.product_id', 'wb.store_id', 'wb.calendar_date']) }}
                                            AS inventory_daily_sk,
    dp.product_sk,
    ds.store_sk,
    dd.date_key                             AS snapshot_date_key,

    wb.product_id,
    wb.store_id,
    wb.calendar_date                        AS snapshot_date,
    wb.units_moved_today,
    wb.closing_stock_units                  AS end_of_day_stock

FROM with_balance wb
LEFT JOIN dim_product dp ON wb.product_id    = dp.product_id
LEFT JOIN dim_store   ds ON wb.store_id      = ds.store_id
LEFT JOIN dim_date    dd ON wb.calendar_date = dd.calendar_date
