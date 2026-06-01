-- tests/assert_lifecycle_dates_are_sequential.sql
-- Custom test: order lifecycle timestamps must be in logical order.
-- paid_at must be after order_date, shipped_at after paid_at, etc.

SELECT order_id
FROM {{ ref('fct_order_lifecycle') }}
WHERE
    (paid_at IS NOT NULL AND paid_at < ordered_at)
    OR (shipped_at IS NOT NULL AND shipped_at < paid_at)
    OR (delivered_at IS NOT NULL AND delivered_at < shipped_at)
