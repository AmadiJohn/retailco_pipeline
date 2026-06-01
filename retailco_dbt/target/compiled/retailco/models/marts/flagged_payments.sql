select
    payment_id, order_id,
    customer_id, payment_method_id,
    amount_paid, currency,
    payment_status, payment_type,
    reference, paid_at,
    payment_flag   as anomaly_type,
    updated_at,
    current_timestamp as flagged_at
from "warehouse"."marts_staging"."stg_payments"
where payment_flag != 'valid'