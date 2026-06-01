
  
    

  create  table "warehouse"."marts_marts"."fct_sales__dbt_tmp"
  
  
    as
  
  (
    with orders as (
    select * from "warehouse"."marts_staging"."stg_orders"
    where is_deleted = false
),
items  as (select * from "warehouse"."marts_staging"."stg_order_items"),
lines  as (
    select
        i.order_item_id, i.order_id,
        o.customer_id, o.store_id,
        o.employee_id, i.product_id,
        o.ordered_at  as order_date,
        i.quantity, i.unit_price,
        i.discount_pct, i.line_total,
        o.status       as order_status
    from items i join orders o using (order_id)
),
dc as (select * from "warehouse"."marts_marts"."dim_customer"),
dp as (select * from "warehouse"."marts_marts"."dim_product"),
ds as (select * from "warehouse"."marts_marts"."dim_store"),
de as (select * from "warehouse"."marts_marts"."dim_employee"),
dd as (select * from "warehouse"."marts_marts"."dim_date")
select
    md5(cast(coalesce(cast(l.order_item_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))                                          as sales_sk,
    dc.customer_sk, dp.product_sk,
    ds.store_sk,   de.employee_sk,
    dd.date_key                                   as order_date_key,
    l.order_id, l.order_item_id,
    l.quantity, l.unit_price,
    l.discount_pct,
    round(l.unit_price * (l.discount_pct / 100), 2) as discount_amount,
    l.line_total                                  as revenue,
    l.line_total - (dp.cost_price * l.quantity)   as gross_profit,
    l.order_status
from lines l
left join dc
    on l.customer_id  = dc.customer_id
    and l.order_date >= dc.valid_from
    and (dc.valid_to is null
         or l.order_date < dc.valid_to)
left join dp
    on l.product_id   = dp.product_id
    and l.order_date >= dp.valid_from
    and (dp.valid_to is null
         or l.order_date < dp.valid_to)
left join ds on l.store_id    = ds.store_id
left join de on l.employee_id = de.employee_id
left join dd on l.order_date::date = dd.calendar_date
  );
  