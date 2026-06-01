-- models/marts/dim_date.sql
-- ─────────────────────────────────────────────────────────────
-- Dimension: Date
-- Covers 2023-01-01 to 2025-12-31 (3 years).
-- Includes Nigeria-specific public holidays.
-- Uses a surrogate key = YYYYMMDD integer (e.g., 20240115).
--
-- Plain English: This table has one row per calendar day.
-- Every fact table joins to this table to enable time-based analysis
-- (group by month, filter by quarter, flag weekends, etc.)
-- ─────────────────────────────────────────────────────────────

WITH date_spine AS (
    -- Generate one row per day from 2023-01-01 to 2025-12-31
    SELECT generate_series(
        '2023-01-01'::DATE,
        '2025-12-31'::DATE,
        INTERVAL '1 day'
    )::DATE AS calendar_date
),

-- Nigerian public holidays (fixed + approximate floating dates)
nigerian_holidays AS (
    SELECT unnest(ARRAY[
        -- 2023
        '2023-01-01'::DATE, '2023-01-02', '2023-04-07', '2023-04-10',
        '2023-04-21', '2023-05-01', '2023-06-12', '2023-06-28',
        '2023-06-29', '2023-10-01', '2023-12-25', '2023-12-26',
        -- 2024
        '2024-01-01', '2024-03-29', '2024-04-01', '2024-04-10',
        '2024-04-11', '2024-05-01', '2024-06-12', '2024-10-01',
        '2024-12-25', '2024-12-26',
        -- 2025
        '2025-01-01', '2025-01-29', '2025-04-18', '2025-04-21',
        '2025-05-01', '2025-06-06', '2025-06-12', '2025-10-01',
        '2025-12-25', '2025-12-26'
    ]) AS holiday_date
),

final AS (
    SELECT
        -- Surrogate key: integer YYYYMMDD
        TO_CHAR(d.calendar_date, 'YYYYMMDD')::INT   AS date_key,
        d.calendar_date,

        -- Year/Quarter/Month/Week
        EXTRACT(YEAR  FROM d.calendar_date)::INT    AS year,
        EXTRACT(QUARTER FROM d.calendar_date)::INT  AS quarter,
        EXTRACT(MONTH FROM d.calendar_date)::INT    AS month_number,
        TO_CHAR(d.calendar_date, 'Month')           AS month_name,
        TO_CHAR(d.calendar_date, 'Mon')             AS month_abbr,
        EXTRACT(WEEK  FROM d.calendar_date)::INT    AS week_of_year,

        -- Day details
        EXTRACT(DAY   FROM d.calendar_date)::INT    AS day_of_month,
        EXTRACT(DOW   FROM d.calendar_date)::INT    AS day_of_week,   -- 0=Sun, 6=Sat
        TO_CHAR(d.calendar_date, 'Day')             AS day_name,

        -- Flags
        CASE WHEN EXTRACT(DOW FROM d.calendar_date) IN (0,6)
             THEN TRUE ELSE FALSE END               AS is_weekend,

        CASE WHEN h.holiday_date IS NOT NULL
             THEN TRUE ELSE FALSE END               AS is_public_holiday,

        -- Useful groupings
        TO_CHAR(d.calendar_date, 'YYYY-MM')         AS year_month,
        'Q' || EXTRACT(QUARTER FROM d.calendar_date)::TEXT
            || ' ' || EXTRACT(YEAR FROM d.calendar_date)::TEXT AS year_quarter

    FROM date_spine d
    LEFT JOIN nigerian_holidays h ON d.calendar_date = h.holiday_date
)

SELECT * FROM final
ORDER BY calendar_date
