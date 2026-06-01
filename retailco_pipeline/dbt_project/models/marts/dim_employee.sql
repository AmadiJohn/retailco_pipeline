-- models/marts/dim_employee.sql

WITH stg AS (SELECT * FROM {{ ref('stg_employees') }})

SELECT
    {{ dbt_utils.generate_surrogate_key(['employee_id']) }} AS employee_sk,
    employee_id,
    first_name,
    last_name,
    first_name || ' ' || last_name  AS full_name,
    email,
    role,
    store_id,
    hire_date,
    is_deleted
FROM stg
