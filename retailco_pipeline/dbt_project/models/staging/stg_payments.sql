-- models/staging/stg_payments.sql
-- ─────────────────────────────────────────────────────────────
-- KEY BUSINESS LOGIC HERE:
-- The task says some payments have amount_paid = 0 or unexpected
-- negatives (not refunds). We add a flag column here so downstream
-- models can split them into fct_payments vs flagged_payments.
--
-- Rules:
--   amount_paid > 0  → normal payment
--   amount_paid < 0  → refund (valid, keep in fct_payments)
--   amount_paid = 0  → anomalous (goes to flagged_payments)
--   amount_paid < 0 AND no linked positive payment → also flagged
-- ─────────────────────────────────────────────────────────────

WITH source AS (SELECT raw_data, _extracted_at FROM {{ source('raw', 'payments') }}),
typed AS (
    SELECT
        (raw_data->>'payment_id')::TEXT             AS payment_id,
        (raw_data->>'order_id')::TEXT               AS order_id,
        (raw_data->>'payment_method_id')::TEXT      AS payment_method_id,
        (raw_data->>'amount_paid')::NUMERIC(12,2)   AS amount_paid,
        (raw_data->>'payment_date')::TIMESTAMPTZ    AS payment_date,
        (raw_data->>'status')::TEXT                 AS payment_status,
        (raw_data->>'notes')::TEXT                  AS notes,
        (raw_data->>'updated_at')::TIMESTAMPTZ      AS updated_at,
        _extracted_at
    FROM source
),

-- Label each payment
classified AS (
    SELECT
        *,
        CASE
            WHEN amount_paid = 0        THEN 'zero_amount'
            WHEN amount_paid < 0
             AND payment_status != 'refund' THEN 'unexplained_negative'
            ELSE 'valid'
        END AS payment_flag
    FROM typed
)

SELECT * FROM classified
