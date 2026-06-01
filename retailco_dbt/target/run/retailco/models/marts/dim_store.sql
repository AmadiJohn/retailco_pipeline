
  
    

  create  table "warehouse"."marts_marts"."dim_store__dbt_tmp"
  
  
    as
  
  (
    with stg as (
    select * from "warehouse"."marts_staging"."stg_stores"
)
select
    md5(cast(coalesce(cast(store_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))
                   as store_sk,
    store_id, store_name,
    city, state, address,
    phone, manager_name, opened_date
from stg
  );
  