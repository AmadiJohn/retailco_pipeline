-- models/marts/flagged_payments.sql
-- ─────────────────────────────────────────────────────────────
-- Data Quality Artifact: Flagged Payments
--
-- NOT a fact table — does NOT appear in the bus matrix.
-- Isolates anomalous payment records so analysts can investigate.
-- These are EXCLUDED from fct_payments so they don't corrupt revenue.
-- ─────────────────────────────────────────────────────────────

WITH stg AS (
    SELECT * FROM {{ ref('stg_payments') }}
    WHERE payment_flag != 'valid'   -- only the bad ones
)

SELECT
    payment_id,
    order_id,
    payment_method_id,
    amount_paid,
    payment_date,
    payment_status,
    notes,
    payment_flag                    AS anomaly_type,
    updated_at,
    CURRENT_TIMESTAMP               AS flagged_at
FROM stg
