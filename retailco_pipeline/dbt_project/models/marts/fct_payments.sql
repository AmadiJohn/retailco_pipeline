-- models/marts/fct_payments.sql
-- ─────────────────────────────────────────────────────────────
-- Fact: Payments (Transactional Grain — one row per payment event)
--
-- Plain English:
-- One order can have multiple payment events (e.g., partial payment
-- then a refund). This table includes both normal payments AND refunds
-- (negative amounts). Anomalous payments (zero, unexplained negatives)
-- are EXCLUDED — they go to the flagged_payments table instead.
-- ─────────────────────────────────────────────────────────────

WITH payments AS (
    SELECT * FROM {{ ref('stg_payments') }}
    WHERE payment_flag = 'valid'          -- exclude anomalous payments
),

dim_payment_method AS (SELECT * FROM {{ ref('dim_payment_method') }}),
dim_date           AS (SELECT * FROM {{ ref('dim_date') }}),
dim_store          AS (
    -- Get store via order
    SELECT s.store_sk, o.order_id
    FROM {{ ref('dim_store') }} s
    JOIN {{ ref('stg_orders') }} o ON o.store_id = s.store_id
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['p.payment_id']) }}         AS payment_sk,

    -- Dimension FKs
    dpm.payment_method_sk,
    dd.date_key                                                      AS payment_date_key,
    ds.store_sk,

    -- Natural keys
    p.payment_id,
    p.order_id,

    -- Measures
    p.amount_paid,
    CASE WHEN p.amount_paid < 0 THEN TRUE ELSE FALSE END             AS is_refund,
    p.payment_status,
    p.notes

FROM payments p
LEFT JOIN dim_payment_method dpm ON p.payment_method_id = dpm.payment_method_id
LEFT JOIN dim_date dd             ON p.payment_date::DATE = dd.calendar_date
LEFT JOIN dim_store ds            ON p.order_id = ds.order_id
