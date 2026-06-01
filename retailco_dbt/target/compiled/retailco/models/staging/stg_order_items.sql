with source as (
    select raw_data, _extracted_at
    from "warehouse"."raw"."order_items"
),
typed as (
    select
        (raw_data->>'id')::text                    as order_item_id,
        (raw_data->>'orderId')::text               as order_id,
        (raw_data->>'productId')::text             as product_id,
        (raw_data->>'quantity')::int               as quantity,
        (raw_data->>'unitPrice')::numeric(12,2)    as unit_price,
        coalesce(
            (raw_data->>'discountPct')::numeric(10,4),
            0
        )                                          as discount_pct,
        (raw_data->>'lineTotal')::numeric(12,2)    as line_total,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed