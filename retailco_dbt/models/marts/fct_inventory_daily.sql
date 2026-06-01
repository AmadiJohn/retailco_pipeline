with movements as (
    select * from {{ ref('stg_inventory_movements') }}
),
combos as (
    select distinct product_id, store_id from movements
),
dates as (
    select calendar_date from {{ ref('dim_date') }}
),
grid as (
    select c.product_id, c.store_id, d.calendar_date
    from combos c cross join dates d
),
daily as (
    select
        product_id, store_id,
        moved_at::date as movement_date,
        sum(case
            when movement_type = 'IN'  then quantity
            when movement_type = 'OUT' then -quantity
            else quantity
        end)           as net_units
    from movements
    group by product_id, store_id, moved_at::date
),
balanced as (
    select
        g.product_id, g.store_id, g.calendar_date,
        coalesce(d.net_units, 0) as units_moved,
        sum(coalesce(d.net_units, 0)) over (
            partition by g.product_id, g.store_id
            order by g.calendar_date
            rows between unbounded preceding
                     and current row
        )                        as end_of_day_stock
    from grid g
    left join daily d
        on  g.product_id     = d.product_id
        and g.store_id       = d.store_id
        and g.calendar_date  = d.movement_date
),
dp as (
    select * from {{ ref('dim_product') }}
    where is_current = true
),
ds as (select * from {{ ref('dim_store') }}),
dd as (select * from {{ ref('dim_date') }})
select
    {{ dbt_utils.generate_surrogate_key([
        'b.product_id','b.store_id','b.calendar_date'
    ]) }}                         as inventory_daily_sk,
    dp.product_sk, ds.store_sk,
    dd.date_key                   as snapshot_date_key,
    b.product_id, b.store_id,
    b.calendar_date               as snapshot_date,
    b.units_moved, b.end_of_day_stock
from balanced b
left join dp on b.product_id    = dp.product_id
left join ds on b.store_id      = ds.store_id
left join dd on b.calendar_date = dd.calendar_date