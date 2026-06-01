
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  select order_item_id, revenue
from "warehouse"."marts_marts"."fct_sales"
where revenue <= 0
  
  
      
    ) dbt_internal_test