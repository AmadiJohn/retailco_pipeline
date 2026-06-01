with source as (
    select raw_data, _extracted_at
    from {{ source('raw', 'stores') }}
),
typed as (
    select
        (raw_data->>'id')::text                    as store_id,
        (raw_data->>'name')::text                  as store_name,
        (raw_data->>'city')::text                  as city,
        (raw_data->>'state')::text                 as state,
        (raw_data->>'address')::text               as address,
        (raw_data->>'phone')::text                 as phone,
        (raw_data->>'managerName')::text           as manager_name,
        (raw_data->>'openedDate')::date            as opened_date,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed