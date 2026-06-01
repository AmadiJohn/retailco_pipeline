
  create view "warehouse"."marts_staging"."stg_customers__dbt_tmp"
    
    
  as (
    with source as (
    select raw_data, _extracted_at
    from "warehouse"."raw"."customers"
),
typed as (
    select
        (raw_data->>'id')::text                    as customer_id,
        (raw_data->>'firstName')::text             as first_name,
        (raw_data->>'lastName')::text              as last_name,
        (raw_data->>'email')::text                 as email,
        (raw_data->>'phone')::text                 as phone,
        (raw_data->>'segment')::text               as segment,
        (raw_data->>'tier')::text                  as tier,
        (raw_data->>'address')::text               as address,
        (raw_data->>'city')::text                  as city,
        (raw_data->>'state')::text                 as state,
        coalesce(
            (raw_data->>'isDeleted')::boolean,
            false
        )                                          as is_deleted,
        (raw_data->>'effectiveFrom')::timestamptz  as effective_from,
        (raw_data->>'registeredAt')::timestamptz   as registered_at,
        (raw_data->>'createdAt')::timestamptz      as created_at,
        (raw_data->>'updatedAt')::timestamptz      as updated_at,
        _extracted_at
    from source
)
select * from typed
  );