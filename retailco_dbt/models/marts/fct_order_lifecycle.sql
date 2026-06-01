with orders as (select * from {{ ref('stg_orders') }}),
dc as (
    select * from {{ ref('dim_customer') }}
    where is_current = true
),
ds as (select * from {{ ref('dim_store') }}),
dd as (select * from {{ ref('dim_date') }})
select
    {{ dbt_utils.generate_surrogate_key(
        ['o.order_id']
    ) }}                                              as lifecycle_sk,
    dc.customer_sk, ds.store_sk,
    dd_order.date_key                                 as order_date_key,
    dd_paid.date_key                                  as paid_date_key,
    dd_shipped.date_key                               as shipped_date_key,
    dd_delivered.date_key                             as delivered_date_key,
    o.order_id, o.ordered_at,
    o.paid_at, o.shipped_at,
    o.delivered_at, o.cancelled_at,
    o.status,
    o.is_deleted                                      as is_cancelled,
    round(extract(epoch from
        (o.paid_at - o.ordered_at))   / 3600, 1)     as hours_to_payment,
    round(extract(epoch from
        (o.shipped_at - o.paid_at))   / 3600, 1)     as hours_to_shipment,
    round(extract(epoch from
        (o.delivered_at - o.shipped_at)) / 3600, 1)  as hours_to_delivery,
    round(extract(epoch from
        (o.delivered_at - o.ordered_at)) / 3600, 1)  as total_hours,
    o.total_amount, o.discount_amount
from orders o
left join dc on o.customer_id = dc.customer_id
left join ds on o.store_id    = ds.store_id
left join dd dd_order
    on o.ordered_at::date   = dd_order.calendar_date
left join dd dd_paid
    on o.paid_at::date      = dd_paid.calendar_date
left join dd dd_shipped
    on o.shipped_at::date   = dd_shipped.calendar_date
left join dd dd_delivered
    on o.delivered_at::date = dd_delivered.calendar_date