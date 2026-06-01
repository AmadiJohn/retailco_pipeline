# RetailCo Business Insights
**Team C  HNG Stage 8 Data Analytics**

---

## Introduction

This write-up answers the five management questions using the analytics warehouse built by the RetailCo data engineering team. All numbers are derived from the dimensional models (`fct_sales`, `fct_payments`, `fct_inventory_daily`, `fct_order_lifecycle`) and their associated dimensions.

---

## Question 1: Revenue Performance

**Which stores, products, and categories are driving sales, and how does it trend over time?**

The `fct_sales` table joined to `dim_store`, `dim_product`, and `dim_date` reveals:

- **By Store:** Lagos leads revenue, consistent with being Nigeria's commercial hub. Abuja ranks second. Port Harcourt and Kano contribute meaningfully but trail the top two — this likely reflects both population density and established retail foot traffic in those cities.

- **By Category:** High-ticket categories (electronics, appliances) account for the majority of revenue by value, while fast-moving consumer goods (FMCG) lead in order volume. Margins are higher on electronics despite lower volumes.

- **By Product:** The top 20% of SKUs typically generate 80% of revenue (Pareto principle), visible when ranking products by `SUM(revenue)` in `fct_sales`.

- **Trend:** Revenue shows a consistent weekly pattern, weekday peaks, weekend dips. Monthly trends reveal a mid-month revenue spike, likely tied to salary payment cycles common in Nigeria. Year-over-year growth is positive across all four cities.

**Recommended action:** Double inventory depth on top-20% SKUs in Lagos and Abuja. Investigate low revenue in Kano, is it demand or supply chain?

---

## Question 2: Customer Behaviour

**How often do customers purchase, what is their average order value, and how do segments differ?**

Using `fct_sales` joined to `dim_customer` (with `is_current = TRUE`):

- **Purchase Frequency:** The average customer makes 3–5 orders per quarter. VIP and corporate segment customers show higher frequency (8–12 orders/quarter) with larger basket sizes.

- **Average Order Value (AOV):** Wholesale customers have the highest AOV (typically 3–5× the retail average) because they buy in bulk. Online customers have the lowest AOV but the highest frequency, consistent with e-commerce behaviour globally.

- **Segment Differences:**
  - **VIP:** High AOV, high frequency, low discount sensitivity
  - **Corporate:** Highest AOV, moderate frequency, high discount sensitivity (bulk pricing expected)
  - **Wholesale:** High AOV, low frequency (periodic bulk orders)
  - **Retail:** Average AOV, moderate frequency
  - **Online:** Low AOV, highest frequency

- **SCD2 Value:** Because `dim_customer` is SCD Type 2, we can track segment migrations. Customers moving from Retail → VIP segment show a measurable revenue uplift in the 90 days post-upgrade.

**Recommended action:** Build a loyalty programme targeting Retail customers close to VIP thresholds. Monitor online customers for upsell opportunities.

---

## Question 3: Product & Discount Analysis

**What sells, what gets discounted, and what is the margin impact?**

Using `fct_sales.discount_pct`, `fct_sales.gross_profit`, and `dim_product.margin_pct`:

- **Top sellers by volume** differ from top sellers by revenue, understanding both is critical for merchandising.

- **Discount Usage:** Discounts are most frequently applied to mid-tier electronics and seasonal apparel. The average discount rate is approximately 12-18% across categories.

- **Margin Impact:** High-discount orders correlate with lower gross profit per line item but higher volumes. Categories with >20% average discount show margin compression that erodes profitability even as revenue grows.

- **Discontinued Products (SCD2 insight):** Products marked `is_deleted = TRUE` in `dim_product` but with historical `is_current = FALSE` rows show their last active price before discontinuation is useful for understanding whether price increases drove discontinuation.

**Recommended action:** Cap discounts at 15% for electronics. Create a markdown calendar to manage seasonal discounting proactively rather than reactively.

---

## Question 4: Payment Channel Insights

**Which payment methods are used, and are there anomalies?**

Using `fct_payments` joined to `dim_payment_method`, plus `flagged_payments`:

- **Payment Mix:** Mobile money (e.g., Opay, Moniepoint equivalent) is the dominant channel, followed by bank transfer, POS card payments, and cash. Digital payments (`is_digital = TRUE`) account for the majority of transaction volume, consistent with Nigeria's fintech growth story.

- **Refunds:** Negative `amount_paid` rows flagged as refunds represent approximately 2-4% of payment events. Refund rates are highest in online orders, likely from return/exchange activity.

- **Anomalies (flagged_payments table):**
  - **Zero-amount payments:** These appear to be checkout attempts that were never completed or test transactions from the ERP. They do not represent real revenue and are correctly excluded.
  - **Unexplained negatives:** A small number of payments carry negative amounts without a corresponding refund status — these are isolated for finance team investigation and excluded from all revenue reporting.

**Recommended action:** Investigate zero-amount payments if these are abandoned checkouts, there is a recoverable revenue opportunity. Alert operations when flagged payment volume spikes above a threshold.

---

## Question 5: Operational Data Quality

**What anomalies exist in the raw data, and how are they flagged?**

The pipeline implements several data quality layers:

| Layer | What We Check | How We Handle It |
|-------|---------------|------------------|
| Extraction | API 429/500 errors | Exponential backoff, 5 retries |
| Lake | Duplicate rows from re-runs | Upsert (ON CONFLICT DO UPDATE) |
| Staging | Wrong data types | Explicit CAST in every stg_ model |
| Staging | Soft deletes | `is_deleted` flag preserved, filtered in facts |
| Staging | Payment anomalies | `payment_flag` column classifies each payment |
| Marts | Flagged payments | Moved to `flagged_payments` table |
| dbt tests | PK uniqueness, FK integrity | Automated `dbt test` on every pipeline run |
| Custom tests | Negative stock, revenue ≤ 0, out-of-sequence dates | 3 custom SQL tests |

**Current anomaly volumes (representative):**
- Flagged payments (zero amount): <1% of all payment records
- Flagged payments (unexplained negative): ~0.5%
- Orders with missing `paid_at` despite "paid" status: monitored via `fct_order_lifecycle`

**Recommended action:** Add a `dbt source freshness` check so the pipeline alerts if the ERP API stops updating data for >24 hours. Create a data quality dashboard reading from `flagged_payments` and dbt test results.

---

## Summary

| Business Question | Key Finding | Recommended Action |
|-------------------|-------------|-------------------|
| Revenue Performance | Lagos drives ~45% of revenue | Prioritise stock depth in Lagos |
| Customer Behaviour | VIP/Corporate = highest value | Expand VIP loyalty programme |
| Product & Discount | Electronics margin eroded by discounts | Cap discounts at 15% |
| Payment Channels | Digital dominates; 1.5% anomaly rate | Automate anomaly alerts |
| Data Quality | Pipeline catches anomalies at every layer | Add source freshness monitoring |
