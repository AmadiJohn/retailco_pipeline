with snap as (
    select * from {{ ref('snap_products') }}
)
select
    {{ dbt_utils.generate_surrogate_key(
        ['product_id','dbt_updated_at']
    ) }}                                       as product_sk,
    product_id, sku, product_name,
    category, sub_category, brand, supplier,
    cost_price, selling_price,
    selling_price - cost_price                 as gross_margin,
    case when cost_price > 0
         then round(
             (selling_price - cost_price)
             / cost_price * 100, 2)
         else null
    end                                        as margin_pct,
    is_deleted,
    dbt_valid_from                             as valid_from,
    dbt_valid_to                               as valid_to,
    case when dbt_valid_to is null
         then true else false
    end                                        as is_current
from snap