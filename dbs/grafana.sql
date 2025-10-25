-- Create the user (role) with password
CREATE USER grafana WITH PASSWORD 'secret';

-- Create the database owned by the user
CREATE DATABASE grafana OWNER grafana;

-- Grant all privileges on the database to the user
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;

-- Connect to the grafana database to set additional permissions
\c grafana

-- Grant schema permissions (important for PostgreSQL 15+)
GRANT ALL ON SCHEMA public TO grafana;

-- Ensure the user can create tables in the public schema
GRANT CREATE ON SCHEMA public TO grafana;