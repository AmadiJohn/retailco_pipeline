with source as (
    select raw_data, _extracted_at
    from "warehouse"."raw"."inventory_movements"
),
typed as (
    select
        (raw_data->>'id')::text                    as movement_id,
        (raw_data->>'productId')::text             as product_id,
        (raw_data->>'storeId')::text               as store_id,
        (raw_data->>'movementType')::text          as movement_type,
        (raw_data->>'quantity')::int               as quantity,
        (raw_data->>'referenceId')::text           as reference_id,
        (raw_data->>'referenceType')::text         as reference_type,
        (raw_data->>'notes')::text                 as notes,
        (raw_data->>'movedAt')::timestamptz        as moved_at,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed