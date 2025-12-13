-- Create Gitea database and user (run as a superuser, e.g., postgres)
CREATE USER gitea WITH PASSWORD 'gitea';
CREATE DATABASE gitea OWNER gitea;

\c gitea

-- Ensure the user can manage objects in public schema
GRANT ALL ON SCHEMA public TO gitea;
GRANT CREATE ON SCHEMA public TO gitea;
