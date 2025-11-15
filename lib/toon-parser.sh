#!/usr/bin/env bash
# TOON parser - parses dependency graph data in TOON format
# Provides efficient querying functions for bash scripts

set -eo pipefail

# Resolve relative path to absolute path
_resolve_path() {
    local input_path="$1"
    local cwd="${2:-$(pwd)}"

    # If already absolute, return as-is
    if [[ "$input_path" == /* ]]; then
        echo "$input_path"
        return 0
    fi

    # Resolve relative path
    local resolved="$cwd/$input_path"
    # Normalize the path (remove ./ and resolve ../)
    python3 -c "import os; print(os.path.normpath('$resolved'))" 2>/dev/null || echo "$resolved"
}

# Find file in graph (supports both absolute and relative paths)
_find_file_in_graph() {
    local graph_file="$1"
    local target_file="$2"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    # Try as-is first (absolute path)
    if grep -q "^FILE:$target_file$" "$graph_file" 2>/dev/null; then
        echo "$target_file"
        return 0
    fi

    # Try resolving as relative path
    local abs_path=$(_resolve_path "$target_file")
    if grep -q "^FILE:$abs_path$" "$graph_file" 2>/dev/null; then
        echo "$abs_path"
        return 0
    fi

    # Search for partial matches (filename only)
    local matches=$(grep "^FILE:" "$graph_file" | cut -d: -f2- | grep "/${target_file}$" | head -1)
    if [ -n "$matches" ]; then
        echo "$matches"
        return 0
    fi

    # Try without leading slash for relative paths
    matches=$(grep "^FILE:" "$graph_file" | cut -d: -f2- | grep "${target_file}$" | head -1)
    if [ -n "$matches" ]; then
        echo "$matches"
        return 0
    fi

    return 1
}

toon_get_file_info() {
    local graph_file="$1"
    local target_file="$2"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    # Resolve the file path first
    local resolved_file=$(_find_file_in_graph "$graph_file" "$target_file")
    if [ $? -ne 0 ]; then
        return 1
    fi

    awk -v target="$resolved_file" '
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

    toon_get_file_info "$graph_file" "$target_file" | grep "^IMPORTS:" | cut -d: -f2- | tr ',' '\n' | grep -v '^$' || true
}

toon_get_exports() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_file_info "$graph_file" "$target_file" | grep "^EXPORTS:" | cut -d: -f2- | tr ',' '\n' | grep -v '^$' || true
}

toon_get_importers() {
    local graph_file="$1"
    local target_file="$2"

    toon_get_file_info "$graph_file" "$target_file" | grep "^IMPORTEDBY:" | cut -d: -f2- | tr ',' '\n' | grep -v '^$' || true
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

    _find_file_in_graph "$graph_file" "$target_file" >/dev/null 2>&1
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

    grep "^CIRCULAR:" "$graph_file" 2>/dev/null | cut -d: -f2- | sed 's/>/ -> /g' || true
}

toon_get_deadcode() {
    local graph_file="$1"

    if [ ! -f "$graph_file" ]; then
        return 1
    fi

    grep "^DEADCODE:" "$graph_file" 2>/dev/null | cut -d: -f2- || true
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

    toon_list_files "$graph_file" | grep "$pattern" || true
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f _resolve_path
    export -f _find_file_in_graph
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
