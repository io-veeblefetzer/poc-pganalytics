\c pocpg;

-- Activate the following extensions
CREATE EXTENSION postgis;
CREATE EXTENSION pg_analytics;

-- No telemetry please
ALTER SYSTEM SET paradedb.pg_search_telemetry TO 'off';


