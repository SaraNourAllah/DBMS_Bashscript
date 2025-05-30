#!/usr/bin/bash

function database_menu() {
    local dbname="$1"
    PS3="[$dbname] - Select an option: "
    select option in "Create Table" "List Tables" "Drop Table" "Insert Into Table" "Select From Table" "Delete From Table" "Update Table" "Back"; do
        case $REPLY in
            1) create_table "$dbname" ;;
            2) list_tables "$dbname" ;;
            3) drop_table "$dbname" ;;
            4) insert_into_table "$dbname" ;;
            5) select_from_table "$dbname" ;;
            6) delete_from_table "$dbname" ;;
            7) update_table "$dbname" ;;
            8) break ;;
            *) echo "Invalid option." ;;
        esac
    done
}