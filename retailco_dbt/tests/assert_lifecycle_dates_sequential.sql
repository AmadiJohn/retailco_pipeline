select order_id
from {{ ref('fct_order_lifecycle') }}
where
    (paid_at is not null and paid_at < ordered_at)
    or (shipped_at is not null and shipped_at < paid_at)
    or (delivered_at is not null and delivered_at < shipped_at)