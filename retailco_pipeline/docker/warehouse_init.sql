/*
 Warehouse database initialisation
 dlt and dbt will create tables here; we just pre-create schemas
*/

CREATE SCHEMA IF NOT EXISTS raw;        -- dlt loads here (mirror of lake raw)
CREATE SCHEMA IF NOT EXISTS staging;    -- dbt staging models
CREATE SCHEMA IF NOT EXISTS marts;      -- dbt dimensional models (facts + dims)
CREATE SCHEMA IF NOT EXISTS snapshots;  -- dbt SCD2 snapshots

-- Grant permissions to wh_user
GRANT USAGE ON SCHEMA raw TO wh_user;
GRANT USAGE ON SCHEMA staging TO wh_user;
GRANT USAGE ON SCHEMA marts TO wh_user;
GRANT USAGE ON SCHEMA snapshots TO wh_user;

GRANT CREATE ON SCHEMA raw TO wh_user;
GRANT CREATE ON SCHEMA staging TO wh_user;
GRANT CREATE ON SCHEMA marts TO wh_user;
GRANT CREATE ON SCHEMA snapshots TO wh_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw TO wh_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA staging TO wh_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA marts TO wh_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA snapshots TO wh_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO wh_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO wh_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA marts GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO wh_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA snapshots GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO wh_user;
