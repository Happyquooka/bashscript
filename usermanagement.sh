#!/bin/bash
set -e
bash -n "$0" || { echo "Error: Script syntax error"; exit 1; }

# Set PostgreSQL admin credentials
export PGPASSWORD=admin
PSQL="psql -U admin -h localhost -d sample_db"

# Check database connection
echo "Checking database connection..."
if $PSQL -t -c "SELECT 1;" >/dev/null 2>&1; then
    echo "Connected to database 'sample_db'."
else
    echo "Error: Failed to connect to database 'sample_db'. Check credentials or database status."
    unset PGPASSWORD
    exit 1
fi

# Function to check if a user exists
check_user_exists() {
    local username=$1
    if $PSQL -t -c "SELECT 1 FROM pg_roles WHERE rolname = '$username';" 2>/dev/null | grep -q 1; then
        return 0
    else
        return 1
    fi
}

# Function to create a user
create_user() {
    read -p "Enter username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    if check_user_exists "$username"; then
        echo "Error: User $username already exists."
        return 1
    fi
    read -p "Enter password for $username: " password
    if [ -z "$password" ]; then
        echo "Error: Password cannot be empty."
        return 1
    fi
    read -p "Grant superuser privileges? (y/n): " superuser
    echo "Creating user $username..."
    $PSQL -c "CREATE ROLE \"$username\" WITH LOGIN PASSWORD '$password';" 2>/dev/null || {
        echo "Error: Failed to create user $username."
        return 1
    }
    if [ "$superuser" = "y" ]; then
        $PSQL -c "ALTER ROLE \"$username\" WITH SUPERUSER;" 2>/dev/null || {
            echo "Error: Failed to grant superuser privileges."
            return 1
        }
    fi
    echo "User $username created successfully."
}

# Function to modify a user (create if not exists, or update privileges)
modify_user() {
    read -p "Enter username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    read -p "Enter password for $username: " password
    if [ -z "$password" ]; then
        echo "Error: Password cannot be empty."
        return 1
    fi
    read -p "Grant superuser privileges? (y/n): " superuser
    if check_user_exists "$username"; then
        echo "User $username exists. Modifying privileges..."
        $PSQL -c "ALTER ROLE \"$username\" WITH PASSWORD '$password';" 2>/dev/null || {
            echo "Error: Failed to modify user $username."
            return 1
        }
        if [ "$superuser" = "y" ]; then
            $PSQL -c "ALTER ROLE \"$username\" WITH SUPERUSER;" 2>/dev/null || {
                echo "Error: Failed to grant superuser privileges."
                return 1
            }
        else
            $PSQL -c "ALTER ROLE \"$username\" WITH NOSUPERUSER;" 2>/dev/null || {
                echo "Error: Failed to revoke superuser privileges."
                return 1
            }
        fi
        echo "User $username modified successfully."
    else
        echo "Creating user $username..."
        $PSQL -c "CREATE ROLE \"$username\" WITH LOGIN PASSWORD '$password';" 2>/dev/null || {
            echo "Error: Failed to create user $username."
            return 1
        }
        if [ "$superuser" = "y" ]; then
            $PSQL -c "ALTER ROLE \"$username\" WITH SUPERUSER;" 2>/dev/null || {
                echo "Error: Failed to grant superuser privileges."
                return 1
            }
        fi
        echo "User $username created successfully."
    fi
}

# Function to check if a user exists
check_user() {
    read -p "Enter username to check: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    if check_user_exists "$username"; then
        echo "User $username exists."
        $PSQL -c "\du $username" 2>/dev/null || {
            echo "Error: Failed to retrieve user details."
            return 1
        }
    else
        echo "User $username does not exist."
    fi
}

# Function to change a user’s password
change_password() {
    read -p "Enter username: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    if check_user_exists "$username"; then
        read -p "Enter new password for $username: " password
        if [ -z "$password" ]; then
            echo "Error: Password cannot be empty."
            return 1
        fi
        $PSQL -c "ALTER ROLE \"$username\" WITH PASSWORD '$password';" 2>/dev/null || {
            echo "Error: Failed to change password for $username."
            return 1
        }
        echo "Password for $username changed successfully."
    else
        echo "Error: User $username does not exist."
        return 1
    fi
}

# Function to lock a user
lock_user() {
    read -p "Enter username to lock: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    if check_user_exists "$username"; then
        $PSQL -c "ALTER ROLE \"$username\" WITH NOLOGIN;" 2>/dev/null || {
            echo "Error: Failed to lock user $username."
            return 1
        }
        $PSQL -c "REVOKE CONNECT ON DATABASE sample_db FROM \"$username\";" 2>/dev/null || {
            echo "Error: Failed to revoke database access for $username."
            return 1
        }
        echo "User $username locked successfully."
    else
        echo "Error: User $username does not exist."
        return 1
    fi
}

# Function to unlock a user
unlock_user() {
    read -p "Enter username to unlock: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    if check_user_exists "$username"; then
        $PSQL -c "ALTER ROLE \"$username\" WITH LOGIN;" 2>/dev/null || {
            echo "Error: Failed to unlock user $username."
            return 1
        }
        $PSQL -c "GRANT CONNECT ON DATABASE sample_db TO \"$username\";" 2>/dev/null || {
            echo "Error: Failed to grant database access for $username."
            return 1
        }
        echo "User $username unlocked successfully."
    else
        echo "Error: User $username does not exist."
        return 1
    fi
}

# Function to drop a user
drop_user() {
    read -p "Enter username to drop: " username
    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty."
        return 1
    fi
    if check_user_exists "$username"; then
        read -p "Are you sure you want to drop user $username? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            $PSQL -c "DROP ROLE \"$username\";" 2>/dev/null || {
                echo "Error: Failed to drop user $username."
                return 1
            }
            echo "User $username dropped successfully."
        else
            echo "Operation cancelled."
        fi
    else
        echo "Error: User $username does not exist."
        return 1
    fi
}

# Main menu
while true; do
    echo -e "\nPostgreSQL User Management Menu"
    echo "1. Create a user"
    echo "2. Modify a user"
    echo "3. Check if a user exists"
    echo "4. Change a user’s password"
    echo "5. Lock a user"
    echo "6. Unlock a user"
    echo "7. Drop a user"
    echo "8. Exit"
    read -p "Select an option (1-8): " choice
    case $choice in
        1) create_user ;;
        2) modify_user ;;
        3) check_user ;;
        4) change_password ;;
        5) lock_user ;;
        6) unlock_user ;;
        7) drop_user ;;
        8) echo "Exiting..."; unset PGPASSWORD; exit 0 ;;
        *) echo "Invalid option. Please select 1-8." ;;
    esac
done
