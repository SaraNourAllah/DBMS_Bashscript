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

function insert_into_table() {
    local dbname="$1"
    local tablename
    local table_path
    local meta_path

    read -p "Enter table name: " tablename

    table_path="$DB_PATH/$dbname/$tablename"
    meta_path="$DB_PATH/$dbname/.$tablename.meta"

    if [[ ! -f "$table_path" || ! -f "$meta_path" ]]; then
        echo "Table or metadata file does not exist."
        return
    fi

    mapfile -t cols_meta < <(grep -v '^$' "$meta_path")

    if [[ ${#cols_meta[@]} -eq 0 ]]; then
        echo "Metadata file is empty or invalid."
        return
    fi

    record=""

    for line in "${cols_meta[@]}"; do
        IFS=: read -r col_name col_type is_pk <<< "$line"

        while true; do
            read -p "Enter value for column '$col_name' ($col_type): " value

            if [[ "$col_type" == "int" ]]; then
                if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                    echo "Invalid integer for column '$col_name'. Try again."
                    continue
                fi
            elif [[ "$col_type" == "string" ]]; then
                if [[ "$value" == *:* ]]; then
                    echo "Invalid string: colon ':' not allowed."
                    continue
                fi
            fi

            if [[ "$is_pk" == "yes" ]]; then

                col_index=$(( $(grep -n "^$col_name:" "$meta_path" | cut -d: -f1) ))

                if awk -F: -v val="$value" -v idx="$col_index" 'NR>0 {if ($idx==val) exit 1}' "$table_path"; then

                    :
                else
                    echo "Duplicate primary key value '$value'. Try again."
                    continue
                fi
            fi

            break
        done

        record+="$value:"
    done

    record="${record%:}"
    echo "$record" >> "$table_path"
    echo "Record inserted successfully."
}

function select_from_table() {
    local dbname="$1"
    read -p "Enter table name: " tablename

    local table_path="$DB_PATH/$dbname/$tablename"
    local meta_path="$DB_PATH/$dbname/.$tablename.meta"

    if [[ ! -f "$table_path" || ! -f "$meta_path" ]]; then
        echo "Table or metadata file does not exist."
        return
    fi

    awk -F: '{printf "%-15s", $1}' "$meta_path"
    echo

    awk -F: '{
        for(i=1; i<=NF; i++) printf "%-15s", $i;
        print ""
    }' "$table_path"
}


function delete_from_table() {
    local dbname="$1"
    read -p "Enter table name: " tablename

    local table="$DB_PATH/$dbname/$tablename"
    local meta="$DB_PATH/$dbname/.$tablename.meta"

    if [[ ! -f "$table" || ! -f "$meta" ]]; then
        echo "Table not found."
        return
    fi

    echo "Delete by:"
    select method in "Primary Key" "Cancel"; do
        case $REPLY in
            1)
                local pk_col=$(awk -F: '$3 == "yes" { print $1 }' "$meta")
                read -p "Enter value of primary key ($pk_col): " pk_val

                local pk_index=$(awk -F: -v pk="$pk_col" '{ if($1 == pk) print NR-1 }' "$meta")
                if [[ -z "$pk_index" ]]; then
                    echo "Primary key not found in meta."
                    return
                fi

                if grep -q "^.*\(:.*\)\{${pk_index}\}$pk_val:" "$table" || grep -q "^$pk_val:" "$table"; then
                    grep -v "^.*\(:.*\)\{${pk_index}\}$pk_val[:$]" "$table" > "$table.tmp"
                    mv "$table.tmp" "$table"
                    echo "Row deleted."
                else
                    echo "No row found with primary key = $pk_val."
                fi
                break
                ;;
            2)
                echo "Delete cancelled."
                break
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    done
}

function update_table() {
    local dbname="$1"
    read -p "Enter table name: " tablename

    local table="$DB_PATH/$dbname/$tablename"
    local meta="$DB_PATH/$dbname/.$tablename.meta"

    if [[ ! -f "$table" || ! -f "$meta" ]]; then
        echo "Table not found."
        return
    fi

    local pk_col=$(awk -F: '$3 == "yes" { print $1 }' "$meta")
    local pk_index=$(awk -F: -v pk="$pk_col" '{ if($1 == pk) print NR }' "$meta")

    read -p "Enter value of primary key ($pk_col) to update: " pk_val

    local line_num=$(awk -F: -v idx="$pk_index" -v val="$pk_val" '{
        if ($idx == val) {
            print NR
            found=1
            exit
        }
    } END { if (!found) exit 1 }' "$table")

    if [[ -z "$line_num" ]]; then
        echo "No row found with that primary key value."
        return
    fi

    echo "Which column do you want to update?"
    mapfile -t cols_meta < "$meta"
    for (( i=0; i<${#cols_meta[@]}; i++ )); do
        IFS=: read -r col_name _ <<< "${cols_meta[i]}"
        echo "$((i+1))) $col_name"
    done

    read -p "Enter column number: " col_choice
    if ! [[ "$col_choice" =~ ^[1-9][0-9]*$ && "$col_choice" -le "${#cols_meta[@]}" ]]; then
        echo "Invalid choice."
        return
    fi

    IFS=: read -r upd_col upd_type is_pk <<< "${cols_meta[$((col_choice-1))]}"
    if [[ "$is_pk" == "yes" ]]; then
        echo "Cannot update primary key."
        return
    fi

    read -p "Enter new value for '$upd_col' ($upd_type): " new_val
    if [[ "$upd_type" == "int" && ! "$new_val" =~ ^[0-9]+$ ]]; then
        echo "Invalid integer."
        return
    fi
    if [[ "$upd_type" == "string" && "$new_val" == *:* ]]; then
        echo "Invalid string (colon not allowed)."
        return
    fi

    awk -v line="$line_num" -v idx="$col_choice" -v new="$new_val" -F: 'BEGIN{OFS=":"}{
        if (NR == line) {
            $idx = new
        }
        print
    }' "$table" > "$table.tmp" && mv "$table.tmp" "$table"

    echo "Record updated."
}