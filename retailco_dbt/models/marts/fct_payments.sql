with payments as (
    select * from {{ ref('stg_payments') }}
    where payment_flag = 'valid'
),
dpm as (select * from {{ ref('dim_payment_method') }}),
dd  as (select * from {{ ref('dim_date') }})
select
    {{ dbt_utils.generate_surrogate_key(
        ['p.payment_id']
    ) }}                                     as payment_sk,
    dpm.payment_method_sk,
    dd.date_key                              as payment_date_key,
    p.payment_id, p.order_id,
    p.customer_id, p.amount_paid,
    p.currency, p.payment_status,
    p.payment_type,
    case when p.amount_paid < 0
         then true else false
    end                                      as is_refund,
    p.paid_at
from payments p
left join dpm on p.payment_method_id = dpm.payment_method_id
left join dd  on p.paid_at::date     = dd.calendar_date