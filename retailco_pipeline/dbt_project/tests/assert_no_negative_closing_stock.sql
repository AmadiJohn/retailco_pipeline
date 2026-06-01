-- tests/assert_no_negative_closing_stock.sql
-- Custom test: inventory should never go below zero (business rule)
-- If this returns any rows, the test FAILS.

SELECT
    product_id,
    store_id,
    snapshot_date,
    end_of_day_stock
FROM {{ ref('fct_inventory_daily') }}
WHERE end_of_day_stock < 0
