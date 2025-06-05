#!/bin/bash

# Exit on any error
set -e

# Function to check if a user exists
check_user_exists() {
    local username=$1
    if psql -U postgres -t -c "SELECT 1 FROM pg_roles WHERE rolname = '$username';" | grep -q 1; then
        return 0
    else
        return 1
    fi
}

# Function to create or modify a user
create_or_modify_user() {
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
        sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH PASSWORD '$password';"
        if [ "$superuser" = "y" ]; then
            sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH SUPERUSER;"
        else
            sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH NOSUPERUSER;"
        fi
        echo "User $username modified successfully."
    else
        echo "Creating user $username..."
        sudo -u postgres psql -c "CREATE ROLE \"$username\" WITH LOGIN PASSWORD '$password';"
        if [ "$superuser" = "y" ]; then
            sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH SUPERUSER;"
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
        sudo -u postgres psql -c "\du $username"
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
        sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH PASSWORD '$password';"
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
        sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH NOLOGIN;"
        sudo -u postgres psql -c "REVOKE CONNECT ON DATABASE sample_db FROM \"$username\";"
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
        sudo -u postgres psql -c "ALTER ROLE \"$username\" WITH LOGIN;"
        sudo -u postgres psql -c "GRANT CONNECT ON DATABASE sample_db TO \"$username\";"
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
            sudo -u postgres psql -c "DROP ROLE \"$username\";"
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
    echo "1. Create or modify a user"
    echo "2. Check if a user exists"
    echo "3. Change a user’s password"
    echo "4. Lock a user"
    echo "5. Unlock a user"
    echo "6. Drop a user"
    echo "7. Exit"
    read -p "Select an option (1-7): " choice

    case $choice in
        1) create_or_modify_user ;;
        2) check_user ;;
        3) change_password ;;
        4) lock_user ;;
        5) unlock_user ;;
        6) drop_user ;;
        7) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please select 1-7." ;;
    esac
done
