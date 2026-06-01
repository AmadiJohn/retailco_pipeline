-- tests/assert_sales_revenue_positive.sql
-- Custom test: revenue on individual sale lines must be positive.
-- Refunds are in fct_payments, not fct_sales. So all sales should > 0.

SELECT order_item_id, revenue
FROM {{ ref('fct_sales') }}
WHERE revenue <= 0
