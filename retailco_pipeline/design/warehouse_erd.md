# RetailCo Warehouse ERD

## Entity Relationship Diagram (Text Format)

---

### Dimensions

```
dim_date
├── date_key (PK, INT)          ← YYYYMMDD surrogate key
├── calendar_date (DATE)
├── year, quarter, month_number
├── month_name, month_abbr
├── week_of_year, day_of_month
├── day_of_week, day_name
├── is_weekend (BOOLEAN)
└── is_public_holiday (BOOLEAN)


dim_customer  [SCD2]
├── customer_sk (PK, TEXT)      ← surrogate key (hash of id + version)
├── customer_id (TEXT)          ← natural key (NOT unique — multiple versions)
├── first_name, last_name, full_name
├── email, phone
├── address, city
├── segment
├── is_deleted (BOOLEAN)
├── valid_from (TIMESTAMPTZ)    ← SCD2 columns
├── valid_to (TIMESTAMPTZ)      ← NULL means "current version"
└── is_current (BOOLEAN)


dim_product   [SCD2]
├── product_sk (PK, TEXT)       ← surrogate key
├── product_id (TEXT)           ← natural key
├── product_name, sku
├── category
├── unit_price (NUMERIC)
├── cost_price (NUMERIC)
├── gross_margin (NUMERIC)
├── margin_pct (NUMERIC)
├── supplier
├── is_deleted (BOOLEAN)
├── valid_from (TIMESTAMPTZ)    ← SCD2 columns
├── valid_to (TIMESTAMPTZ)
└── is_current (BOOLEAN)


dim_store
├── store_sk (PK, TEXT)         ← surrogate key
├── store_id (TEXT)             ← natural key
├── store_name
├── city, region, address
├── manager_id
└── opened_date (DATE)


dim_employee
├── employee_sk (PK, TEXT)      ← surrogate key
├── employee_id (TEXT)
├── first_name, last_name, full_name
├── email, role
├── store_id (TEXT)
├── hire_date (DATE)
└── is_deleted (BOOLEAN)


dim_payment_method
├── payment_method_sk (PK, TEXT) ← surrogate key
├── payment_method_id (TEXT)
├── method_name
├── provider
└── is_digital (BOOLEAN)
```

---

### Fact Tables

```
fct_sales   [Transactional — grain: order_item_id]
├── sales_sk (PK, TEXT)
├── customer_sk (FK → dim_customer.customer_sk)
├── product_sk (FK → dim_product.product_sk)
├── store_sk (FK → dim_store.store_sk)
├── employee_sk (FK → dim_employee.employee_sk)
├── order_date_key (FK → dim_date.date_key)
├── order_id (TEXT)             ← degenerate dimension
├── order_item_id (TEXT)        ← degenerate dimension
├── quantity (INT)
├── unit_price (NUMERIC)
├── discount_pct (NUMERIC)
├── discount_amount (NUMERIC)
├── revenue (NUMERIC)           ← additive measure
├── gross_profit (NUMERIC)      ← additive measure
└── order_status (TEXT)


fct_payments   [Transactional — grain: payment_id]
├── payment_sk (PK, TEXT)
├── payment_method_sk (FK → dim_payment_method.payment_method_sk)
├── store_sk (FK → dim_store.store_sk)
├── payment_date_key (FK → dim_date.date_key)
├── payment_id (TEXT)
├── order_id (TEXT)
├── amount_paid (NUMERIC)       ← semi-additive (refunds are negative)
├── is_refund (BOOLEAN)
└── payment_status (TEXT)


fct_inventory_daily   [Periodic Snapshot — grain: product × store × day]
├── inventory_daily_sk (PK, TEXT)
├── product_sk (FK → dim_product.product_sk)
├── store_sk (FK → dim_store.store_sk)
├── snapshot_date_key (FK → dim_date.date_key)
├── product_id (TEXT)
├── store_id (TEXT)
├── snapshot_date (DATE)
├── units_moved_today (INT)
└── end_of_day_stock (INT)      ← semi-additive (can SUM across products, NOT across dates)


fct_order_lifecycle   [Accumulating Snapshot — grain: order_id]
├── lifecycle_sk (PK, TEXT)
├── customer_sk (FK → dim_customer.customer_sk)
├── store_sk (FK → dim_store.store_sk)
├── order_date_key (FK → dim_date.date_key)
├── paid_date_key (FK → dim_date.date_key)
├── shipped_date_key (FK → dim_date.date_key)
├── delivered_date_key (FK → dim_date.date_key)
├── order_id (TEXT)
├── ordered_at, pending_at, paid_at, shipped_at, delivered_at
├── status (TEXT)
├── is_cancelled (BOOLEAN)
├── hours_to_payment (NUMERIC)
├── hours_to_shipment (NUMERIC)
├── hours_to_delivery (NUMERIC)
├── total_hours_to_delivery (NUMERIC)
├── total_amount (NUMERIC)
└── discount_amount (NUMERIC)
```

---

### Data Quality Artifact

```
flagged_payments   [NOT a fact table — no FK to dims]
├── payment_id (PK, TEXT)
├── order_id (TEXT)
├── payment_method_id (TEXT)
├── amount_paid (NUMERIC)
├── payment_date (TIMESTAMPTZ)
├── payment_status (TEXT)
├── notes (TEXT)
├── anomaly_type (TEXT)         ← 'zero_amount' | 'unexplained_negative'
└── flagged_at (TIMESTAMPTZ)
```

---

## Key Design Decisions

1. **All fact table FKs are surrogate keys:** Never a natural keys. This is Kimball rule 1.
2. **SCD2 joins:** fct_sales joins dim_customer/dim_product using date range matching so historical segment/price is preserved.
3. **Refunds:** Stay in fct_payments as negative amount_paid with is_refund=TRUE. Excluded from revenue SUM using WHERE is_refund = FALSE.
4. **Flagged payments:** Excluded from fct_payments entirely. Stored separately for data quality investigation.
5. **Soft deletes:** Filtered from facts but kept in SCD2 snapshots as the final "closed" version.
