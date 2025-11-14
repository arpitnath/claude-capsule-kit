#!/usr/bin/env bash
# TOON parser - parses dependency graph data in TOON format
# Provides efficient querying functions for bash scripts

set -eo pipefail

toon_get_file_info() {
    local graph_file="$1"
    local target_file="$2"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    awk -v target="$target_file" '
        BEGIN { in_file=0; found=0 }
        /^FILE:/ {
            if ($0 == "FILE:" target) {
                in_file=1
                found=1
                print
                next
            } else {
                in_file=0
            }
        }
        /^---$/ { in_file=0 }
        in_file { print }
        END { exit !found }
    ' "$graph_file"
}

toon_get_imports() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_file_info "$graph_file" "$target_file" | grep "^IMPORTS:" | cut -d: -f2- | tr ',' '\n' | grep -v '^$'
}

toon_get_exports() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_file_info "$graph_file" "$target_file" | grep "^EXPORTS:" | cut -d: -f2- | tr ',' '\n' | grep -v '^$'
}

toon_get_importers() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_file_info "$graph_file" "$target_file" | grep "^IMPORTEDBY:" | cut -d: -f2- | tr ',' '\n' | grep -v '^$'
}

toon_get_language() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_file_info "$graph_file" "$target_file" | grep "^LANG:" | cut -d: -f2-
}

toon_count_importers() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_importers "$graph_file" "$target_file" | wc -l | tr -d ' '
}

toon_file_exists() {
    local graph_file="$1"
    local target_file="$2"

    grep -q "^FILE:$target_file$" "$graph_file" 2>/dev/null
}

toon_list_files() {
    local graph_file="$1"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    grep "^FILE:" "$graph_file" | cut -d: -f2-
}

toon_get_circular() {
    local graph_file="$1"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    grep "^CIRCULAR:" "$graph_file" | cut -d: -f2-
}

toon_get_deadcode() {
    local graph_file="$1"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    grep "^DEADCODE:" "$graph_file" | cut -d: -f2-
}

toon_count_files() {
    local graph_file="$1"

    toon_list_files "$graph_file" | wc -l | tr -d ' '
}

toon_get_meta() {
    local graph_file="$1"
    local key="${2:-}"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    if [ -z "$key" ]; then
        grep "^META:" "$graph_file" | cut -d: -f2-
    else
        grep "^META:" "$graph_file" | cut -d: -f2- | grep "^${key}=" | cut -d= -f2-
    fi
}

toon_search_files() {
    local graph_file="$1"
    local pattern="$2"

    toon_list_files "$graph_file" | grep "$pattern"
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f toon_get_file_info
    export -f toon_get_imports
    export -f toon_get_exports
    export -f toon_get_importers
    export -f toon_get_language
    export -f toon_count_importers
    export -f toon_file_exists
    export -f toon_list_files
    export -f toon_get_circular
    export -f toon_get_deadcode
    export -f toon_count_files
    export -f toon_get_meta
    export -f toon_search_files
fi
