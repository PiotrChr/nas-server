-- as a superuser (e.g., postgres):
CREATE USER immich WITH PASSWORD 'immichpass';
CREATE DATABASE immich OWNER immich;

\c immich

-- prerequisite
CREATE EXTENSION IF NOT EXISTS cube;

-- earthdistance itself
CREATE EXTENSION IF NOT EXISTS earthdistance;

CREATE EXTENSION IF NOT EXISTS vector;  -- pgvector