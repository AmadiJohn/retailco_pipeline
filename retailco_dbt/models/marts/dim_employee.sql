with stg as (
    select * from {{ ref('stg_employees') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['employee_id']) }}
                             as employee_sk,
    employee_id, store_id,
    first_name, last_name,
    first_name || ' ' || last_name as full_name,
    email, role, hired_date, is_deleted
from stg