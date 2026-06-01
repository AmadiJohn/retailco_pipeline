
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  -- Only flag negative stock AFTER the first IN movement
-- Early dates before stock arrives naturally show negative
-- running balances which is expected behaviour
with first_movement as (
    select
        product_id,
        store_id,
        min(snapshot_date) as first_date
    from "warehouse"."marts_marts"."fct_inventory_daily"
    where units_moved > 0
    group by product_id, store_id
)
select
    f.product_id,
    f.store_id,
    f.snapshot_date,
    f.end_of_day_stock
from "warehouse"."marts_marts"."fct_inventory_daily" f
join first_movement fm
    on  f.product_id   = fm.product_id
    and f.store_id     = fm.store_id
    and f.snapshot_date > fm.first_date
where f.end_of_day_stock < 0
  
  
      
    ) dbt_internal_test