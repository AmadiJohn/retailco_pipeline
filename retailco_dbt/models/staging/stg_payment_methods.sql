with source as (
    select raw_data, _extracted_at
    from {{ source('raw', 'payment_methods') }}
),
typed as (
    select
        (raw_data->>'id')::text                    as payment_method_id,
        (raw_data->>'name')::text                  as method_name,
        (raw_data->>'provider')::text              as provider,
        coalesce(
            (raw_data->>'isDigital')::boolean,
            false
        )                                          as is_digital,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed