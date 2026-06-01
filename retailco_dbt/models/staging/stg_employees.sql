with source as (
    select raw_data, _extracted_at
    from {{ source('raw', 'employees') }}
),
typed as (
    select
        (raw_data->>'id')::text                    as employee_id,
        (raw_data->>'storeId')::text               as store_id,
        (raw_data->>'firstName')::text             as first_name,
        (raw_data->>'lastName')::text              as last_name,
        (raw_data->>'email')::text                 as email,
        (raw_data->>'role')::text                  as role,
        (raw_data->>'hiredDate')::date             as hired_date,
        coalesce(
            (raw_data->>'isDeleted')::boolean,
            false
        )                                          as is_deleted,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed