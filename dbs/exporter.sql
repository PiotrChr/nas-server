CREATE USER exporter WITH PASSWORD 'exporter';
GRANT pg_monitor TO exporter;
GRANT pg_read_all_settings TO exporter;
GRANT pg_read_all_stats TO exporter;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
