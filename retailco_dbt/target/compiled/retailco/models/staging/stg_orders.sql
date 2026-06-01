with source as (
    select raw_data, _extracted_at
    from "warehouse"."raw"."orders"
),
typed as (
    select
        (raw_data->>'id')::text                       as order_id,
        (raw_data->>'customerId')::text               as customer_id,
        (raw_data->>'storeId')::text                  as store_id,
        (raw_data->>'employeeId')::text               as employee_id,
        (raw_data->>'status')::text                   as status,
        (raw_data->>'discountCode')::text             as discount_code,
        (raw_data->>'discountAmount')::numeric(12,2)  as discount_amount,
        (raw_data->>'totalAmount')::numeric(12,2)     as total_amount,
        (raw_data->>'orderedAt')::timestamptz         as ordered_at,
        (raw_data->>'paidAt')::timestamptz            as paid_at,
        (raw_data->>'shippedAt')::timestamptz         as shipped_at,
        (raw_data->>'deliveredAt')::timestamptz       as delivered_at,
        (raw_data->>'cancelledAt')::timestamptz       as cancelled_at,
        (raw_data->>'createdAt')::timestamptz         as created_at,
        (raw_data->>'updatedAt')::timestamptz         as updated_at,
        case when (raw_data->>'cancelledAt') is not null
             then true else false
        end                                           as is_deleted,
        _extracted_at
    from source
)
select * from typed