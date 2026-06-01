with snap as (
    select * from {{ ref('snap_customers') }}
)
select
    {{ dbt_utils.generate_surrogate_key(
        ['customer_id','dbt_updated_at']
    ) }}                           as customer_sk,
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