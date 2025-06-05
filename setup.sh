#!/bin/bash

# Exit on any error
set -e

# Function to check if PostgreSQL is installed
check_postgresql_installed() {
    if command -v psql &> /dev/null; then
        echo "PostgreSQL is already installed."
        return 0
    else
        echo "PostgreSQL is not installed."
        return 1
    fi
}

# Function to install PostgreSQL
install_postgresql() {
    echo "Installing PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    echo "PostgreSQL installation complete."
}

# Function to check if PostgreSQL is running
check_postgresql_running() {
    if psql -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo "PostgreSQL service is running."
        return 0
    else
        echo "PostgreSQL service is not running."
        return 1
    fi
}

# Function to start PostgreSQL
start_postgresql() {
    echo "Attempting to start PostgreSQL..."
    if sudo service postgresql start; then
        echo "PostgreSQL started using service command."
        return 0
    else
        echo "Failed to start PostgreSQL using service command. Trying pg_ctl..."
        # Find PostgreSQL data directory
        PGDATA=$(psql -U postgres -t -c "SHOW data_directory;" 2>/dev/null | xargs)
        if [ -n "$PGDATA" ]; then
            if sudo -u postgres pg_ctl -D "$PGDATA" start; then
                echo "PostgreSQL started using pg_ctl."
                return 0
            else
                echo "Failed to start PostgreSQL using pg_ctl."
                return 1
            fi
        else
            echo "Could not determine PostgreSQL data directory."
            return 1
        fi
    fi
}

# Main script
echo "Starting PostgreSQL setup..."

# Check and install PostgreSQL
if ! check_postgresql_installed; then
    install_postgresql
fi

# Check if PostgreSQL is running, start if necessary
if ! check_postgresql_running; then
    if ! start_postgresql; then
        echo "Error: Could not start PostgreSQL. Exiting."
        exit 1
    fi
fi

# Create users and database
echo "Setting up PostgreSQL users and database..."
sudo -u postgres psql <<EOF
-- Create database if it doesn't exist
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sample_db') THEN
      CREATE DATABASE sample_db;
   END IF;
END
\$\$;

-- Create users
DO \$\$
BEGIN
   FOR i IN 1..5 LOOP
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'user' || i) THEN
         EXECUTE 'CREATE USER user' || i || ' WITH PASSWORD ''password' || i || '''';
         EXECUTE 'GRANT ALL PRIVILEGES ON DATABASE sample_db TO user' || i;
      END IF;
   END LOOP;
END
\$\$;

-- Connect to sample_db
\c sample_db

-- Create tables if they don't exist
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'employees') THEN
      CREATE TABLE employees (
          id SERIAL PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          department VARCHAR(50),
          salary NUMERIC(10,2)
      );
   END IF;
END
\$\$;

DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'projects') THEN
      CREATE TABLE projects (
          project_id SERIAL PRIMARY KEY,
          project_name VARCHAR(100) NOT NULL,
          start_date DATE,
          assigned_to INTEGER REFERENCES employees(id)
      );
   END IF;
END
\$\$;

-- Insert sample data if tables are empty
INSERT INTO employees (name, department, salary)
SELECT 'John Doe', 'Engineering', 75000.00
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE name = 'John Doe');

INSERT INTO employees (name, department, salary)
SELECT 'Jane Smith', 'Marketing', 65000.00
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE name = 'Jane Smith');

INSERT INTO projects (project_name, start_date, assigned_to)
SELECT 'Website Redesign', '2025-06-01', 1
WHERE NOT EXISTS (SELECT 1 FROM projects WHERE project_name = 'Website Redesign');

INSERT INTO projects (project_name, start_date, assigned_to)
SELECT 'Market Analysis', '2025-07-01', 2
WHERE NOT EXISTS (SELECT 1 FROM projects WHERE project_name = 'Market Analysis');

EOF

if [ $? -eq 0 ]; then
    echo "PostgreSQL setup complete. Database 'sample_db' created with 5 users and tables."
else
    echo "Error: Failed to set up PostgreSQL users or database."
    exit 1
fi
