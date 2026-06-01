with stg as (
    select * from {{ ref('stg_stores') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['store_id']) }}
                   as store_sk,
    store_id, store_name,
    city, state, address,
    phone, manager_name, opened_date
from stg