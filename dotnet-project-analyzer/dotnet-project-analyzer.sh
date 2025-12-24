#!/bin/bash

# .NET Code Analyzer Script (Optimized)
# Analyzes C# code to count meaningful lines of code
# Uses awk for fast processing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Temp directory for data storage
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# AWK script for counting meaningful lines (much faster than bash loops)
AWK_COUNTER='
BEGIN {
    meaningful = 0
    non_empty = 0
    in_multiline_comment = 0
}
{
    # Trim whitespace
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    
    # Skip empty lines
    if (length($0) == 0) next
    
    non_empty++
    
    # Handle multi-line comments
    if (in_multiline_comment) {
        if ($0 ~ /\*\//) in_multiline_comment = 0
        next
    }
    
    if ($0 ~ /^\/\*/ && $0 !~ /\*\//) {
        in_multiline_comment = 1
        next
    }
    
    # Skip non-meaningful lines
    if ($0 == "{") next
    if ($0 == "}") next
    if ($0 == "};") next
    if ($0 ~ /^using[[:space:]]/) next
    if ($0 ~ /^namespace[[:space:]]/) next
    if ($0 ~ /^\/\//) next
    if ($0 ~ /^\/\/\//) next
    if ($0 ~ /^\/\*/) next
    if ($0 ~ /^\*/) next
    if ($0 ~ /^\*\//) next
    if ($0 ~ /^"[^"]*"$/) next
    if ($0 ~ /^\+/) next
    if ($0 ~ /^\./) next
    if ($0 ~ /^\[.*\]$/) next
    if ($0 ~ /^#region/) next
    if ($0 ~ /^#endregion/) next
    if ($0 ~ /^#pragma/) next
    if ($0 ~ /^#if/) next
    if ($0 ~ /^#else/) next
    if ($0 ~ /^#endif/) next
    if ($0 ~ /^#nullable/) next
    if ($0 == "get;") next
    if ($0 == "set;") next
    if ($0 == "init;") next
    if ($0 == "get") next
    if ($0 == "set") next
    
    meaningful++
}
END {
    printf "%d %d", meaningful, non_empty
}
'

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
    
    local i=1
    
    echo "$current_dir" > "$TEMP_DIR/dirs.txt"
    echo -e "  ${BLUE}[$i]${NC} . (Current directory)"
    i=$((i + 1))
    
    dirname "$current_dir" >> "$TEMP_DIR/dirs.txt"
    echo -e "  ${BLUE}[$i]${NC} .. (Parent directory)"
    i=$((i + 1))
    
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

# Function to get hash for a path
get_path_hash() {
    # Use md5sum on Linux, md5 on macOS
    if command -v md5sum &> /dev/null; then
        echo "$1" | md5sum | cut -d' ' -f1
    else
        echo "$1" | md5 | cut -d' ' -f1
    fi
}

# Function to find the project a cs file belongs to
find_project_for_file() {
    local cs_file="$1"
    local dir=$(dirname "$cs_file")
    
    while [[ "$dir" != "/" ]] && [[ "$dir" != "." ]] && [[ -n "$dir" ]]; do
        # Check cache first
        local dir_hash=$(get_path_hash "$dir")
        local cache_file="$TEMP_DIR/dircache_$dir_hash"
        
        if [[ -f "$cache_file" ]]; then
            cat "$cache_file"
            return
        fi
        
        local csproj=$(find "$dir" -maxdepth 1 -name "*.csproj" -type f 2>/dev/null | head -1)
        if [[ -n "$csproj" ]]; then
            echo "$csproj" > "$cache_file"
            echo "$csproj"
            return
        fi
        
        dir=$(dirname "$dir")
    done
    
    echo ""
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
    
    # Get all csproj files
    echo -e "${BLUE}Finding projects...${NC}"
    find "$folder" -name "*.csproj" -type f 2>/dev/null | sort > "$TEMP_DIR/projects.txt"
    total_csproj_count=$(wc -l < "$TEMP_DIR/projects.txt" | tr -d '[:space:]')
    
    # Initialize project data files and count NuGet
    while IFS= read -r csproj; do
        local nuget=$(grep -c '<PackageReference' "$csproj" 2>/dev/null || echo "0")
        nuget=$(echo "$nuget" | tr -d '[:space:]')
        total_nuget_count=$((total_nuget_count + nuget))
        
        local hash=$(get_path_hash "$csproj")
        echo "0|0|0|$nuget|$csproj" > "$TEMP_DIR/proj_$hash.dat"
    done < "$TEMP_DIR/projects.txt"
    
    echo -e "  Found ${GREEN}$total_csproj_count${NC} projects"
    echo ""
    
    # Get all cs files
    find "$folder" -name "*.cs" -type f 2>/dev/null > "$TEMP_DIR/csfiles.txt"
    total_cs_count=$(wc -l < "$TEMP_DIR/csfiles.txt" | tr -d '[:space:]')
    
    echo -e "${BLUE}Analyzing C# files...${NC}"
    
    # Process files in batches using xargs and parallel awk processing
    local processed=0
    local batch_size=100
    local results_file="$TEMP_DIR/batch_results.txt"
    > "$results_file"
    
    # Process each file with awk (much faster than bash line-by-line)
    while IFS= read -r cs_file; do
        processed=$((processed + 1))
        
        # Show progress every 100 files
        if [[ $((processed % 100)) -eq 0 ]] || [[ $processed -eq $total_cs_count ]]; then
            printf "\r  Processing: %d / %d files" "$processed" "$total_cs_count"
        fi
        
        # Use awk for fast line counting
        local counts=$(awk "$AWK_COUNTER" "$cs_file" 2>/dev/null || echo "0 0")
        local meaningful=$(echo "$counts" | awk '{print $1}')
        local non_empty=$(echo "$counts" | awk '{print $2}')
        
        meaningful=${meaningful:-0}
        non_empty=${non_empty:-0}
        
        total_meaningful_lines=$((total_meaningful_lines + meaningful))
        total_non_empty_lines=$((total_non_empty_lines + non_empty))
        
        # Find project and update
        local project=$(find_project_for_file "$cs_file")
        
        if [[ -n "$project" ]]; then
            local hash=$(get_path_hash "$project")
            local data_file="$TEMP_DIR/proj_$hash.dat"
            
            if [[ -f "$data_file" ]]; then
                IFS='|' read -r p_meaningful p_total p_cs p_nuget p_path < "$data_file"
                p_meaningful=$((p_meaningful + meaningful))
                p_total=$((p_total + non_empty))
                p_cs=$((p_cs + 1))
                echo "$p_meaningful|$p_total|$p_cs|$p_nuget|$p_path" > "$data_file"
            else
                orphan_meaningful=$((orphan_meaningful + meaningful))
                orphan_total=$((orphan_total + non_empty))
                orphan_cs_count=$((orphan_cs_count + 1))
            fi
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
        local proj_name=$(basename "$proj_path" .csproj)
        echo "$meaningful|$proj_name|$cs_count|$nuget|$total" >> "$TEMP_DIR/results.txt"
    done
    
    # Display per-project results
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                    Projects Breakdown                                        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${WHITE}%-40s${NC} ${WHITE}%8s${NC} ${WHITE}%10s${NC} ${WHITE}%12s${NC} ${WHITE}%10s${NC} ${WHITE}%8s${NC} ${CYAN}║${NC}\n" \
        "Project" "Files" "NuGet" "Non-Empty" "Meaningful" "Ratio"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    sort -t'|' -k1 -rn "$TEMP_DIR/results.txt" | while IFS='|' read -r p_meaningful proj_name p_cs p_nuget p_total; do
        local ratio="0.0"
        if [[ $p_total -gt 0 ]]; then
            ratio=$(awk "BEGIN {printf \"%.1f\", ($p_meaningful / $p_total) * 100}")
        fi
        
        if [[ ${#proj_name} -gt 40 ]]; then
            proj_name="${proj_name:0:37}..."
        fi
        
        printf "${CYAN}║${NC} %-40s %8d %10d %12d ${GREEN}%10d${NC} %7s%% ${CYAN}║${NC}\n" \
            "$proj_name" "$p_cs" "$p_nuget" "$p_total" "$p_meaningful" "$ratio"
    done
    
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
    select_folder
    analyze_directory "$SELECTED_FOLDER"
    echo -e "${GREEN}Analysis complete!${NC}"
}

main