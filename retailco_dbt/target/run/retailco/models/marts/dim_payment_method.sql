
  
    

  create  table "warehouse"."marts_marts"."dim_payment_method__dbt_tmp"
  
  
    as
  
  (
    with stg as (
    select * from "warehouse"."marts_staging"."stg_payment_methods"
)
select
    md5(cast(coalesce(cast(payment_method_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))                   as payment_method_sk,
    payment_method_id,
    method_name, provider, is_digital
from stg
  );
  