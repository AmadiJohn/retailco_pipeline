with date_spine as (
    select generate_series(
        '2023-01-01'::date,
        '2025-12-31'::date,
        interval '1 day'
    )::date as calendar_date
),
nigerian_holidays as (
    select unnest(array[
        '2023-01-01'::date,'2023-04-07','2023-04-10',
        '2023-05-01','2023-06-12','2023-10-01',
        '2023-12-25','2023-12-26',
        '2024-01-01','2024-03-29','2024-04-01',
        '2024-05-01','2024-06-12','2024-10-01',
        '2024-12-25','2024-12-26',
        '2025-01-01','2025-04-18','2025-04-21',
        '2025-05-01','2025-06-12','2025-10-01',
        '2025-12-25','2025-12-26'
    ]) as holiday_date
)
select
    to_char(d.calendar_date,'YYYYMMDD')::int   as date_key,
    d.calendar_date,
    extract(year    from d.calendar_date)::int as year,
    extract(quarter from d.calendar_date)::int as quarter,
    extract(month   from d.calendar_date)::int as month_number,
    to_char(d.calendar_date,'Month')           as month_name,
    to_char(d.calendar_date,'Mon')             as month_abbr,
    extract(week    from d.calendar_date)::int as week_of_year,
    extract(day     from d.calendar_date)::int as day_of_month,
    extract(dow     from d.calendar_date)::int as day_of_week,
    to_char(d.calendar_date,'Day')             as day_name,
    case when extract(dow from d.calendar_date) in (0,6)
         then true else false end              as is_weekend,
    case when h.holiday_date is not null
         then true else false end              as is_public_holiday,
    to_char(d.calendar_date,'YYYY-MM')         as year_month
from date_spine d
left join nigerian_holidays h
    on d.calendar_date = h.holiday_date
order by calendar_date