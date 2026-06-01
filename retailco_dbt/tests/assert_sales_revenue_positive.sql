select order_item_id, revenue
from {{ ref('fct_sales') }}
where revenue <= 0