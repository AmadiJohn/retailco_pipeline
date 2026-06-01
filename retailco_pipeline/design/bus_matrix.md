# RetailCo - Kimball Bus Matrix

## What is a Bus Matrix?
A bus matrix is a grid showing which dimensions each fact table uses.
It ensures all fact tables share "conformed" dimensions — meaning the
same dim_customer table is used everywhere, giving consistent answers
across different analyses.

---

## Bus Matrix

| Business Process       | dim_date | dim_customer | dim_product | dim_store | dim_employee | dim_payment_method |
|------------------------|:--------:|:------------:|:-----------:|:---------:|:------------:|:------------------:|
| **fct_sales**          | Yes       | Yes           | Yes         | Yes       | Yes           | No                 |
| **fct_payments**       | Yes       | No           | No          | Yes        | No           | Yes                 |
| **fct_inventory_daily**| Yes       | No           | Yes          | Yes        | No           | No                 |
| **fct_order_lifecycle**| Yes (×4)  | Yes           | No          | Yes        | No           | No                 |

**Notes:**
- `dim_date` appears in every fact table (all analyses are time-based).
- `fct_order_lifecycle` uses `dim_date` four times (one per milestone: ordered, paid, shipped, delivered).
- `dim_customer` and `dim_product` are **SCD Type 2** they have history rows.
- `flagged_payments` is a data quality artifact, NOT a fact table. It is excluded from this matrix.

---

## Grain Definitions

| Fact Table              | Grain (one row per...)              | Type                  |
|-------------------------|-------------------------------------|-----------------------|
| `fct_sales`             | Order line item                     | Transactional         |
| `fct_payments`          | Payment event                       | Transactional         |
| `fct_inventory_daily`   | Product × Store × Calendar Day      | Periodic Snapshot     |
| `fct_order_lifecycle`   | Order (status timestamps fill in)   | Accumulating Snapshot |

---

## Dimension Summary

| Dimension             | Type   | SCD | Surrogate Key | Notes                              |
|-----------------------|--------|-----|---------------|------------------------------------|
| `dim_date`            | Static | N/A | `date_key`    | YYYYMMDD integer                   |
| `dim_customer`        | Type 2 | SCD2| `customer_sk` | Tracks segment & address changes   |
| `dim_product`         | Type 2 | SCD2| `product_sk`  | Tracks price & category changes    |
| `dim_store`           | Type 1 | N/A | `store_sk`    | Stores don't relocate              |
| `dim_employee`        | Type 1 | N/A | `employee_sk` | No history required                |
| `dim_payment_method`  | Type 1 | N/A | `payment_method_sk` | Static lookup table          |
