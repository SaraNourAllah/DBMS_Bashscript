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
function create_table() {
    local dbname="$1"
    read -p "Enter table name: " tablename

    if [[ ! "$tablename" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Invalid table name."
        return
    fi

    if [[ -f "$DB_PATH/$dbname/$tablename" || -f "$DB_PATH/$dbname/.$tablename.meta" ]]; then
        echo "Table already exists."
        return
    fi

    read -p "Enter number of columns: " col_count
    if ! [[ "$col_count" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid column count."
        return
    fi

    pk_set="false"
    touch "$DB_PATH/$dbname/$tablename"
    touch "$DB_PATH/$dbname/.$tablename.meta"

    for (( i=1; i<=col_count; i++ ))
    do
        read -p "Column $i name: " col_name
        while [[ ! "$col_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ || $(grep -c "^$col_name:" "$DB_PATH/$dbname/.$tablename.meta") -ne 0 ]]; do
            echo "Invalid or duplicate column name. Try again."
            read -p "Column $i name: " col_name
        done

        echo "Select data type for column $col_name:"
        select col_type in "int" "string"; do
            if [[ "$col_type" == "int" || "$col_type" == "string" ]]; then
                break
            else
                echo "Invalid choice. Select again."
            fi
        done

        is_pk="no"
        if [[ $pk_set == "false" ]]; then
            echo "Should $col_name be the primary key?"
            select answer in "yes" "no"; do
                case "$answer" in
                    yes)
                        is_pk="yes"
                        pk_set="true"
                        break
                        ;;
                    no)
                        break
                        ;;
                    *)
                        echo "Invalid choice."
                        ;;
                esac
            done
        fi

        echo "$col_name:$col_type:$is_pk" >> "$DB_PATH/$dbname/.$tablename.meta"
    done

    if [[ $pk_set == "false" ]]; then
        echo "Table must have one primary key. Operation canceled."
        rm -f "$DB_PATH/$dbname/$tablename" "$DB_PATH/$dbname/.$tablename.meta"
        return
    fi

    echo "Table '$tablename' created successfully."
}

function list_tables() {
    local dbname="$1"
    echo "Tables in '$dbname':"
    ls "$DB_PATH/$dbname" | grep -v "^\\."
}

function drop_table() {
    local dbname="$1"
    read -p "Enter table name to drop: " tablename
    if [[ -f "$DB_PATH/$dbname/$tablename" ]]; then
        rm "$DB_PATH/$dbname/$tablename" "$DB_PATH/$dbname/.$tablename.meta"
        echo "Table '$tablename' deleted."
    else
        echo "Table not found."
    fi
}