#!/bin/bash

# .NET Code Analyzer Script
# Analyzes C# code to count meaningful lines of code
# Compatible with bash 3.x+

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Temp directory for data storage
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Function to sanitize number (remove whitespace/newlines)
sanitize_num() {
    echo "$1" | tr -d '[:space:]'
}

# Function to display folder selection menu
select_folder() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           .NET Code Analyzer - Folder Selection            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local current_dir="$(pwd)"
    echo -e "${YELLOW}Current directory:${NC} $current_dir"
    echo ""
    echo -e "${GREEN}Available folders:${NC}"
    echo ""
    
    # Get list of directories
    local i=1
    
    # Add current directory as option
    echo "$current_dir" > "$TEMP_DIR/dirs.txt"
    echo -e "  ${BLUE}[$i]${NC} . (Current directory)"
    i=$((i + 1))
    
    # Add parent directory as option
    dirname "$current_dir" >> "$TEMP_DIR/dirs.txt"
    echo -e "  ${BLUE}[$i]${NC} .. (Parent directory)"
    i=$((i + 1))
    
    # List subdirectories
    while IFS= read -r dir; do
        if [[ -d "$dir" ]]; then
            echo "$dir" >> "$TEMP_DIR/dirs.txt"
            echo -e "  ${BLUE}[$i]${NC} $(basename "$dir")"
            i=$((i + 1))
        fi
    done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" | sort)
    
    echo ""
    echo -e "  ${BLUE}[c]${NC} Enter custom path"
    echo -e "  ${BLUE}[q]${NC} Quit"
    echo ""
    
    read -p "Select folder to analyze [1-$((i-1)), c, or q]: " choice
    
    case $choice in
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
        c|C)
            read -p "Enter custom path: " custom_path
            if [[ -d "$custom_path" ]]; then
                SELECTED_FOLDER="$custom_path"
            else
                echo -e "${RED}Invalid path. Exiting.${NC}"
                exit 1
            fi
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -lt $i ]]; then
                SELECTED_FOLDER=$(sed -n "${choice}p" "$TEMP_DIR/dirs.txt")
            else
                echo -e "${RED}Invalid selection. Exiting.${NC}"
                exit 1
            fi
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Selected folder:${NC} $SELECTED_FOLDER"
    echo ""
}

# Function to check if a line is meaningful code
is_meaningful_line() {
    local line="$1"
    
    # Trim leading and trailing whitespace
    local trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Skip empty lines
    [[ -z "$trimmed" ]] && return 1
    
    # Skip single braces (opening or closing)
    [[ "$trimmed" == "{" ]] && return 1
    [[ "$trimmed" == "}" ]] && return 1
    [[ "$trimmed" == "};" ]] && return 1
    
    # Skip using statements
    [[ "$trimmed" =~ ^using[[:space:]] ]] && return 1
    
    # Skip namespace declarations
    [[ "$trimmed" =~ ^namespace[[:space:]] ]] && return 1
    
    # Skip single-line comments
    [[ "$trimmed" =~ ^// ]] && return 1
    
    # Skip XML documentation comments
    [[ "$trimmed" =~ ^/// ]] && return 1
    
    # Skip multi-line comment markers
    [[ "$trimmed" =~ ^/\* ]] && return 1
    [[ "$trimmed" =~ ^\* ]] && return 1
    [[ "$trimmed" =~ ^\*/ ]] && return 1
    
    # Skip lines that are just string continuations (wrapped strings)
    [[ "$trimmed" =~ ^\"[^\"]*\"$ ]] && return 1
    [[ "$trimmed" =~ ^\+ ]] && return 1
    
    # Skip LINQ method chains on new lines (lines starting with .)
    [[ "$trimmed" =~ ^\. ]] && return 1
    
    # Skip attribute-only lines
    [[ "$trimmed" =~ ^\[.*\]$ ]] && return 1
    
    # Skip region directives
    [[ "$trimmed" =~ ^#region ]] && return 1
    [[ "$trimmed" =~ ^#endregion ]] && return 1
    [[ "$trimmed" =~ ^#pragma ]] && return 1
    [[ "$trimmed" =~ ^#if ]] && return 1
    [[ "$trimmed" =~ ^#else ]] && return 1
    [[ "$trimmed" =~ ^#endif ]] && return 1
    [[ "$trimmed" =~ ^#nullable ]] && return 1
    
    # Skip empty accessors
    [[ "$trimmed" == "get;" ]] && return 1
    [[ "$trimmed" == "set;" ]] && return 1
    [[ "$trimmed" == "init;" ]] && return 1
    [[ "$trimmed" == "get" ]] && return 1
    [[ "$trimmed" == "set" ]] && return 1
    
    # If we get here, it's a meaningful line
    return 0
}

# Function to count meaningful lines in a file
count_meaningful_lines() {
    local file="$1"
    local meaningful=0
    local total_non_empty=0
    local in_multiline_comment=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        local trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip empty lines for total count
        [[ -z "$trimmed" ]] && continue
        total_non_empty=$((total_non_empty + 1))
        
        # Handle multi-line comments
        if [[ $in_multiline_comment -eq 1 ]]; then
            if [[ "$trimmed" =~ \*/ ]]; then
                in_multiline_comment=0
            fi
            continue
        fi
        
        if [[ "$trimmed" =~ ^/\* ]] && [[ ! "$trimmed" =~ \*/ ]]; then
            in_multiline_comment=1
            continue
        fi
        
        # Check if line is meaningful
        if is_meaningful_line "$line"; then
            meaningful=$((meaningful + 1))
        fi
    done < "$file"
    
    # Output as single line with space separator
    printf "%d %d" "$meaningful" "$total_non_empty"
}

# Function to count NuGet dependencies from a csproj file
count_nuget_in_csproj() {
    local csproj="$1"
    local count
    count=$(grep -c '<PackageReference' "$csproj" 2>/dev/null || echo "0")
    sanitize_num "$count"
}

# Function to get hash for a path (for file-based storage)
get_path_hash() {
    echo "$1" | md5sum | cut -d' ' -f1
}

# Function to find the project a cs file belongs to
find_project_for_file() {
    local cs_file="$1"
    local dir=$(dirname "$cs_file")
    
    # Walk up the directory tree to find a .csproj file
    while [[ "$dir" != "/" ]] && [[ "$dir" != "." ]]; do
        local csproj=$(find "$dir" -maxdepth 1 -name "*.csproj" -type f 2>/dev/null | head -1)
        if [[ -n "$csproj" ]]; then
            echo "$csproj"
            return
        fi
        dir=$(dirname "$dir")
    done
    
    echo ""
}

# Function to initialize project data file
init_project_data() {
    local csproj="$1"
    local nuget="$2"
    local hash=$(get_path_hash "$csproj")
    # Format: meaningful|total|cs_count|nuget|project_path
    echo "0|0|0|$nuget|$csproj" > "$TEMP_DIR/proj_$hash.dat"
}

# Function to update project data
update_project_data() {
    local csproj="$1"
    local add_meaningful="$2"
    local add_total="$3"
    local hash=$(get_path_hash "$csproj")
    local data_file="$TEMP_DIR/proj_$hash.dat"
    
    if [[ -f "$data_file" ]]; then
        IFS='|' read -r meaningful total cs_count nuget proj_path < "$data_file"
        meaningful=$((meaningful + add_meaningful))
        total=$((total + add_total))
        cs_count=$((cs_count + 1))
        echo "$meaningful|$total|$cs_count|$nuget|$proj_path" > "$data_file"
        return 0
    fi
    return 1
}

# Function to analyze directory
analyze_directory() {
    local folder="$1"
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   Analyzing .NET Code                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Scanning:${NC} $folder"
    echo ""
    
    # Initialize counters
    local total_csproj_count=0
    local total_cs_count=0
    local total_meaningful_lines=0
    local total_non_empty_lines=0
    local total_nuget_count=0
    local orphan_meaningful=0
    local orphan_total=0
    local orphan_cs_count=0
    
    # Get all csproj files and initialize their data
    echo -e "${BLUE}Finding projects...${NC}"
    
    # Store project list
    find "$folder" -name "*.csproj" -type f 2>/dev/null | sort > "$TEMP_DIR/projects.txt"
    total_csproj_count=$(wc -l < "$TEMP_DIR/projects.txt" | tr -d '[:space:]')
    
    while IFS= read -r csproj; do
        local nuget
        nuget=$(count_nuget_in_csproj "$csproj")
        total_nuget_count=$((total_nuget_count + nuget))
        init_project_data "$csproj" "$nuget"
    done < "$TEMP_DIR/projects.txt"
    
    echo -e "  Found ${GREEN}$total_csproj_count${NC} projects"
    echo ""
    
    # Count cs files
    find "$folder" -name "*.cs" -type f 2>/dev/null > "$TEMP_DIR/csfiles.txt"
    total_cs_count=$(wc -l < "$TEMP_DIR/csfiles.txt" | tr -d '[:space:]')
    
    # Process each .cs file
    echo -e "${BLUE}Analyzing C# files...${NC}"
    local processed=0
    
    while IFS= read -r cs_file; do
        processed=$((processed + 1))
        
        # Show progress every 50 files
        if [[ $((processed % 50)) -eq 0 ]] || [[ $processed -eq $total_cs_count ]]; then
            printf "\r  Processing: %d / %d files" "$processed" "$total_cs_count"
        fi
        
        # Count lines in file
        local counts
        counts=$(count_meaningful_lines "$cs_file")
        local meaningful
        local non_empty
        meaningful=$(echo "$counts" | awk '{print $1}')
        non_empty=$(echo "$counts" | awk '{print $2}')
        
        # Sanitize
        meaningful=$(sanitize_num "$meaningful")
        non_empty=$(sanitize_num "$non_empty")
        
        # Default to 0 if empty
        meaningful=${meaningful:-0}
        non_empty=${non_empty:-0}
        
        total_meaningful_lines=$((total_meaningful_lines + meaningful))
        total_non_empty_lines=$((total_non_empty_lines + non_empty))
        
        # Find which project this file belongs to
        local project
        project=$(find_project_for_file "$cs_file")
        
        if [[ -n "$project" ]] && update_project_data "$project" "$meaningful" "$non_empty"; then
            : # Successfully updated
        else
            orphan_meaningful=$((orphan_meaningful + meaningful))
            orphan_total=$((orphan_total + non_empty))
            orphan_cs_count=$((orphan_cs_count + 1))
        fi
    done < "$TEMP_DIR/csfiles.txt"
    
    echo ""
    echo ""
    
    # Calculate total percentage
    local total_percentage="0.0"
    if [[ $total_non_empty_lines -gt 0 ]]; then
        total_percentage=$(awk "BEGIN {printf \"%.1f\", ($total_meaningful_lines / $total_non_empty_lines) * 100}")
    fi
    
    # Collect all project data for sorting
    > "$TEMP_DIR/results.txt"
    for data_file in "$TEMP_DIR"/proj_*.dat; do
        [[ -f "$data_file" ]] || continue
        IFS='|' read -r meaningful total cs_count nuget proj_path < "$data_file"
        local proj_name
        proj_name=$(basename "$proj_path" .csproj)
        echo "$meaningful|$proj_name|$cs_count|$nuget|$total" >> "$TEMP_DIR/results.txt"
    done
    
    # Display per-project results
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                    Projects Breakdown                                        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${WHITE}%-40s${NC} ${WHITE}%8s${NC} ${WHITE}%10s${NC} ${WHITE}%12s${NC} ${WHITE}%10s${NC} ${WHITE}%8s${NC} ${CYAN}║${NC}\n" \
        "Project" "Files" "NuGet" "Non-Empty" "Meaningful" "Ratio"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # Sort by meaningful lines descending and display
    sort -t'|' -k1 -rn "$TEMP_DIR/results.txt" | while IFS='|' read -r p_meaningful proj_name p_cs p_nuget p_total; do
        local ratio="0.0"
        if [[ $p_total -gt 0 ]]; then
            ratio=$(awk "BEGIN {printf \"%.1f\", ($p_meaningful / $p_total) * 100}")
        fi
        
        # Truncate project name if too long
        if [[ ${#proj_name} -gt 40 ]]; then
            proj_name="${proj_name:0:37}..."
        fi
        
        printf "${CYAN}║${NC} %-40s %8d %10d %12d ${GREEN}%10d${NC} %7s%% ${CYAN}║${NC}\n" \
            "$proj_name" "$p_cs" "$p_nuget" "$p_total" "$p_meaningful" "$ratio"
    done
    
    # Show orphan files if any
    if [[ $orphan_cs_count -gt 0 ]]; then
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        local orphan_ratio="0.0"
        if [[ $orphan_total -gt 0 ]]; then
            orphan_ratio=$(awk "BEGIN {printf \"%.1f\", ($orphan_meaningful / $orphan_total) * 100}")
        fi
        printf "${CYAN}║${NC} ${YELLOW}%-40s${NC} %8d %10s %12d ${GREEN}%10d${NC} %7s%% ${CYAN}║${NC}\n" \
            "(Files without project)" "$orphan_cs_count" "-" "$orphan_total" "$orphan_meaningful" "$orphan_ratio"
    fi
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Display summary
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                       Summary Totals                       ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total project files (*.csproj):" "$total_csproj_count"
    printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total C# source files (*.cs):" "$total_cs_count"
    printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total NuGet dependencies:" "$total_nuget_count"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total non-empty lines:" "$total_non_empty_lines"
    printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total meaningful code lines:" "$total_meaningful_lines"
    printf "${CYAN}║${NC} %-40s ${GREEN}%14s%%${NC} ${CYAN}║${NC}\n" "Overall code efficiency ratio:" "$total_percentage"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Main execution
main() {
    # Select folder
    select_folder
    
    # Analyze selected folder
    analyze_directory "$SELECTED_FOLDER"
    
    echo -e "${GREEN}Analysis complete!${NC}"
}

# Run main function
main