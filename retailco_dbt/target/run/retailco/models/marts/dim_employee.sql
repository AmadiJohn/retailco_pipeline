
  
    

  create  table "warehouse"."marts_marts"."dim_employee__dbt_tmp"
  
  
    as
  
  (
    with stg as (
    select * from "warehouse"."marts_staging"."stg_employees"
)
select
    md5(cast(coalesce(cast(employee_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))
                             as employee_sk,
    employee_id, store_id,
    first_name, last_name,
    first_name || ' ' || last_name as full_name,
    email, role, hired_date, is_deleted
from stg
  );
  