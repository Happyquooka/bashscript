#!/bin/bash
set -e
bash -n "$0" || { echo "Error: Script syntax error"; exit 1; }
sudo su <<ROOT
set -e
command -v psql >/dev/null || { echo "Installing PostgreSQL..."; apt-get update; apt-get install -y postgresql postgresql-contrib; echo "PostgreSQL installed."; }
sudo -u postgres psql -d postgres -c "SELECT 1;" >/dev/null 2>&1 || { echo "Starting PostgreSQL..."; service postgresql start && echo "PostgreSQL started." || { echo "Error: Could not start PostgreSQL."; exit 1; }; }
echo "Setting up database..."
sudo -u postgres psql -t -c "SELECT 1 FROM pg_database WHERE datname = 'sample_db';" | grep -q 1 || { sudo -u postgres psql -c "CREATE DATABASE sample_db;" && echo "Database 'sample_db' created." || { echo "Error: Failed to create database."; exit 1; }; } || echo "Database 'sample_db' already exists."
echo "PostgreSQL setup complete."
ROOT
