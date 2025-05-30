#!/usr/bin/bash

DB_PATH="./DB"
mkdir -p "$DB_PATH"

function main_menu() {
    echo "Welcome to Bash DBMS"
    PS3="Main Menu - Select an option: "
    select option in "Create Database" "List Databases" "Connect to Database" "Drop Database" "Exit"; do
        case $REPLY in
            1) create_database ;;
            2) list_databases ;;
            3) connect_database ;;
            4) drop_database ;;
            5) echo "Exit"; break ;;
            *) echo "Invalid option, Try again." ;;
        esac
    done
}

function create_database() {
    read -p "Enter database name: " dbname
    if [[ -d "$DB_PATH/$dbname" ]]; then
        echo "Database already exists."
    else
        mkdir "$DB_PATH/$dbname"
        echo "Database '$dbname' created."
    fi
}

main_menu
