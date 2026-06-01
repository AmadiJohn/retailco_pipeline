with source as (
    select raw_data, _extracted_at
    from "warehouse"."raw"."products"
),
typed as (
    select
        (raw_data->>'id')::text                    as product_id,
        (raw_data->>'sku')::text                   as sku,
        (raw_data->>'name')::text                  as product_name,
        (raw_data->>'category')::text              as category,
        (raw_data->>'subCategory')::text           as sub_category,
        (raw_data->>'brand')::text                 as brand,
        (raw_data->>'supplier')::text              as supplier,
        (raw_data->>'costPrice')::numeric(12,2)    as cost_price,
        (raw_data->>'sellingPrice')::numeric(12,2) as selling_price,
        coalesce(
            (raw_data->>'isDeleted')::boolean,
            false
        )                                          as is_deleted,
        (raw_data->>'effectiveFrom')::timestamptz  as effective_from,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed