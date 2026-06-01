with source as (
    select raw_data, _extracted_at
    from "warehouse"."raw"."payments"
),
typed as (
    select
        (raw_data->>'id')::text                    as payment_id,
        (raw_data->>'orderId')::text               as order_id,
        (raw_data->>'customerId')::text            as customer_id,
        (raw_data->>'paymentMethodId')::text       as payment_method_id,
        (raw_data->>'amountPaid')::numeric(12,2)   as amount_paid,
        (raw_data->>'currency')::text              as currency,
        (raw_data->>'status')::text                as payment_status,
        (raw_data->>'paymentType')::text           as payment_type,
        (raw_data->>'reference')::text             as reference,
        (raw_data->>'paidAt')::timestamptz         as paid_at,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
),
classified as (
    select *,
        case
            when amount_paid = 0
                then 'zero_amount'
            when amount_paid < 0
             and payment_status != 'refund'
                then 'unexplained_negative'
            else 'valid'
        end as payment_flag
    from typed
)
select * from classified