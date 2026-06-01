
  
    

  create  table "warehouse"."marts_marts"."dim_customer__dbt_tmp"
  
  
    as
  
  (
    with snap as (
    select * from "warehouse"."snapshots"."snap_customers"
)
select
    md5(cast(coalesce(cast(customer_id as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(dbt_updated_at as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))                           as customer_sk,
    customer_id,
    first_name, last_name,
    first_name || ' ' || last_name as full_name,
    email, phone, segment, tier,
    address, city, state,
    is_deleted,
    dbt_valid_from                 as valid_from,
    dbt_valid_to                   as valid_to,
    case when dbt_valid_to is null
         then true else false
    end                            as is_current
from snap
  );
  