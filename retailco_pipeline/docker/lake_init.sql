/*
 Lake database initialisation
 Creates the raw schema where extractor writes API data
 Also creates the watermarks table for incremental loading
*/

CREATE SCHEMA IF NOT EXISTS raw;

/*
 Watermarks table: tracks the last successful extract timestamp per entity.
 This is how incremental loading works — next run only fetches rows updated after this point.
*/

CREATE TABLE IF NOT EXISTS raw.watermarks (
    entity_name   TEXT PRIMARY KEY,
    last_updated  TIMESTAMPTZ NOT NULL DEFAULT '1970-01-01T00:00:00Z',
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed watermarks for all 9 entities (start from epoch so first run is a full extract)
INSERT INTO raw.watermarks (entity_name, last_updated) VALUES
    ('customers',           '1970-01-01T00:00:00Z'),
    ('products',            '1970-01-01T00:00:00Z'),
    ('stores',              '1970-01-01T00:00:00Z'),
    ('employees',           '1970-01-01T00:00:00Z'),
    ('orders',              '1970-01-01T00:00:00Z'),
    ('order_items',         '1970-01-01T00:00:00Z'),
    ('payments',            '1970-01-01T00:00:00Z'),
    ('inventory_movements', '1970-01-01T00:00:00Z'),
    ('payment_methods',     '1970-01-01T00:00:00Z')
ON CONFLICT (entity_name) DO NOTHING;

-- Grant the lake user explicit rights on the raw schema and its tables.
GRANT USAGE ON SCHEMA raw TO lake_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw TO lake_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lake_user;
