#!/bin/sh

PG_MOICS_TABLESPACE=/opt/data/pg_monics_data

PGDATABASE=postgres
PGUSER=postgres
PGPASSWORD=postgres

psql -d postgres -c "DROP DATABASE IF EXISTS monics"
psql -d postgres -c "DROP TABLESPACE IF EXISTS monics_data"
psql -d postgres -c "DROP ROLE IF EXISTS monics"

psql -d postgres -c "CREATE ROLE monics WITH LOGIN password 'monics'"
psql -d postgres -c "CREATE TABLESPACE monics_data OWNER monics LOCATION '$PG_MONICS_TABLESPACE'"
psql -d postgres -c "CREATE DATABASE monics WITH OWNER=monics TEMPLATE=template0 TABLESPACE=monics_data"

psql -d postgres -c "COMMENT ON ROLE monics is 'Monics System Database User'"
psql -d postgres -c "COMMENT ON TABLESPACE monics_data is 'The tablespace for the Monics Collection Database'"
psql -d postgres -c "COMMENT ON DATABASE monics is 'Monics Collection Database'"

psql -d monics < schema.sql
psql -d monics < Common.sql

psql -d monics < Beacon.sql
psql -d monics < Carrier.sql
psql -d monics < Transponder.sql
psql -d monics < ModAnalysis.sql
psql -d monics < SaTrace.sql
psql -d monics < ModTrace.sql

