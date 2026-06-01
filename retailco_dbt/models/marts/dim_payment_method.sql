with stg as (
    select * from {{ ref('stg_payment_methods') }}
)
select
    {{ dbt_utils.generate_surrogate_key(
        ['payment_method_id']
    ) }}                   as payment_method_sk,
    payment_method_id,
    method_name, provider, is_digital
from stg