#!/bin/bash

# .NET Code Analyzer Script
# Analyzes C# code in each subfolder and saves results as JSON

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

# JSON output filename
JSON_FILENAME="dotnet-analysis.json"

# AWK script for counting meaningful lines
AWK_COUNTER='
BEGIN {
    meaningful = 0
    non_empty = 0
    in_multiline_comment = 0
}
{
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    
    if (length($0) == 0) next
    
    non_empty++
    
    if (in_multiline_comment) {
        if ($0 ~ /\*\//) in_multiline_comment = 0
        next
    }
    
    if ($0 ~ /^\/\*/ && $0 !~ /\*\//) {
        in_multiline_comment = 1
        next
    }
    
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

# Function to select parent folder
select_folder() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              .NET Code Analyzer - Folder Selection         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local current_dir="$(pwd)"
    echo -e "${YELLOW}Current directory:${NC} $current_dir"
    echo -e "${YELLOW}Each subfolder with .NET projects will be analyzed.${NC}"
    echo -e "${YELLOW}Results will be saved as ${JSON_FILENAME} in each subfolder.${NC}"
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
    
    read -p "Select folder [1-$((i-1)), c, or q]: " choice
    
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

# Function to analyze a single subfolder and save JSON
analyze_subfolder() {
    local folder="$1"
    local folder_name=$(basename "$folder")
    
    # Clear directory cache
    rm -f "$TEMP_DIR"/dircache_* 2>/dev/null || true
    
    # Initialize counters
    local total_csproj_count=0
    local total_cs_count=0
    local total_meaningful_lines=0
    local total_non_empty_lines=0
    local total_nuget_count=0
    
    # Get all csproj files
    find "$folder" -name "*.csproj" -type f 2>/dev/null | sort > "$TEMP_DIR/projects.txt"
    total_csproj_count=$(wc -l < "$TEMP_DIR/projects.txt" | tr -d '[:space:]')
    
    # Skip if no projects found
    if [[ $total_csproj_count -eq 0 ]]; then
        return 1
    fi
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Analyzing: ${YELLOW}$folder_name${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    
    # Count NuGet and init project data
    > "$TEMP_DIR/project_results.txt"
    
    while IFS= read -r csproj; do
        local nuget=$(grep -c '<PackageReference' "$csproj" 2>/dev/null || echo "0")
        nuget=$(echo "$nuget" | tr -d '[:space:]')
        total_nuget_count=$((total_nuget_count + nuget))
        
        local hash=$(get_path_hash "$csproj")
        echo "0|0|0|$nuget|$csproj" > "$TEMP_DIR/proj_$hash.dat"
    done < "$TEMP_DIR/projects.txt"
    
    echo -e "  Projects: ${GREEN}$total_csproj_count${NC}"
    
    # Get all cs files
    find "$folder" -name "*.cs" -type f 2>/dev/null > "$TEMP_DIR/csfiles.txt"
    total_cs_count=$(wc -l < "$TEMP_DIR/csfiles.txt" | tr -d '[:space:]')
    
    echo -e "  C# files: ${GREEN}$total_cs_count${NC}"
    
    # Process each file
    local processed=0
    while IFS= read -r cs_file; do
        processed=$((processed + 1))
        
        if [[ $((processed % 50)) -eq 0 ]] || [[ $processed -eq $total_cs_count ]]; then
            printf "\r  Processing: %d / %d files" "$processed" "$total_cs_count"
        fi
        
        local counts=$(awk "$AWK_COUNTER" "$cs_file" 2>/dev/null || echo "0 0")
        local meaningful=$(echo "$counts" | awk '{print $1}')
        local non_empty=$(echo "$counts" | awk '{print $2}')
        
        meaningful=${meaningful:-0}
        non_empty=${non_empty:-0}
        
        total_meaningful_lines=$((total_meaningful_lines + meaningful))
        total_non_empty_lines=$((total_non_empty_lines + non_empty))
        
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
            fi
        fi
    done < "$TEMP_DIR/csfiles.txt"
    
    echo ""
    
    # Calculate ratio
    local ratio="0.0"
    if [[ $total_non_empty_lines -gt 0 ]]; then
        ratio=$(awk "BEGIN {printf \"%.2f\", ($total_meaningful_lines / $total_non_empty_lines) * 100}")
    fi
    
    # Display projects table
    echo ""
    printf "  ${WHITE}%-35s${NC} ${WHITE}%6s${NC} ${WHITE}%6s${NC} ${WHITE}%10s${NC} ${WHITE}%10s${NC} ${WHITE}%7s${NC}\n" \
        "Project" "Files" "NuGet" "Non-Empty" "Meaning." "Ratio"
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Collect and sort project data for display
    > "$TEMP_DIR/display_results.txt"
    for data_file in "$TEMP_DIR"/proj_*.dat; do
        [[ -f "$data_file" ]] || continue
        IFS='|' read -r p_meaningful p_total p_cs p_nuget p_path < "$data_file"
        local proj_name=$(basename "$p_path" .csproj)
        echo "$p_meaningful|$proj_name|$p_cs|$p_nuget|$p_total" >> "$TEMP_DIR/display_results.txt"
    done
    
    sort -t'|' -k1 -rn "$TEMP_DIR/display_results.txt" | while IFS='|' read -r p_meaningful proj_name p_cs p_nuget p_total; do
        local p_ratio="0.0"
        if [[ $p_total -gt 0 ]]; then
            p_ratio=$(awk "BEGIN {printf \"%.1f\", ($p_meaningful / $p_total) * 100}")
        fi
        
        # Truncate project name if too long
        if [[ ${#proj_name} -gt 35 ]]; then
            proj_name="${proj_name:0:32}..."
        fi
        
        printf "  %-35s %6d %6d %10d ${GREEN}%10d${NC} %6s%%\n" \
            "$proj_name" "$p_cs" "$p_nuget" "$p_total" "$p_meaningful" "$p_ratio"
    done
    
    echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    printf "  ${WHITE}%-35s${NC} %6d %6d %10d ${GREEN}%10d${NC} %6s%%\n" \
        "TOTAL" "$total_cs_count" "$total_nuget_count" "$total_non_empty_lines" "$total_meaningful_lines" "$ratio"
    echo ""
    
    # Build projects JSON array
    local projects_json="["
    local first_project=1
    
    for data_file in "$TEMP_DIR"/proj_*.dat; do
        [[ -f "$data_file" ]] || continue
        IFS='|' read -r p_meaningful p_total p_cs p_nuget p_path < "$data_file"
        local proj_name=$(basename "$p_path" .csproj)
        
        local p_ratio="0.0"
        if [[ $p_total -gt 0 ]]; then
            p_ratio=$(awk "BEGIN {printf \"%.2f\", ($p_meaningful / $p_total) * 100}")
        fi
        
        if [[ $first_project -eq 0 ]]; then
            projects_json="$projects_json,"
        fi
        first_project=0
        
        projects_json="$projects_json
    {
      \"name\": \"$proj_name\",
      \"csFiles\": $p_cs,
      \"nugetDependencies\": $p_nuget,
      \"nonEmptyLines\": $p_total,
      \"meaningfulLines\": $p_meaningful,
      \"ratio\": $p_ratio
    }"
    done
    
    projects_json="$projects_json
  ]"
    
    # Create JSON output
    local json_output="{
  \"repository\": \"$folder_name\",
  \"analyzedAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",
  \"summary\": {
    \"totalProjects\": $total_csproj_count,
    \"totalCsFiles\": $total_cs_count,
    \"totalNugetDependencies\": $total_nuget_count,
    \"totalNonEmptyLines\": $total_non_empty_lines,
    \"totalMeaningfulLines\": $total_meaningful_lines,
    \"meaningfulCodeRatio\": $ratio
  },
  \"projects\": $projects_json
}"
    
    # Save JSON file
    echo "$json_output" > "$folder/$JSON_FILENAME"
    
    echo -e "  ${YELLOW}Saved: $folder/$JSON_FILENAME${NC}"
    echo ""
    
    # Return data for grand total
    echo "$total_meaningful_lines|$total_non_empty_lines|$total_csproj_count|$total_cs_count|$total_nuget_count|$folder_name" >> "$TEMP_DIR/grand_totals.txt"
    
    return 0
}

# Main function
main() {
    select_folder
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   Starting Analysis                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Find all immediate subfolders
    local subfolders=()
    while IFS= read -r subfolder; do
        subfolders+=("$subfolder")
    done < <(find "$SELECTED_FOLDER" -maxdepth 1 -type d ! -path "$SELECTED_FOLDER" | sort)
    
    local total_subfolders=${#subfolders[@]}
    echo -e "${BLUE}Found ${GREEN}$total_subfolders${BLUE} subfolders to check${NC}"
    echo ""
    
    # Initialize grand totals file
    > "$TEMP_DIR/grand_totals.txt"
    
    local analyzed_count=0
    
    # Analyze each subfolder
    for subfolder in "${subfolders[@]}"; do
        if analyze_subfolder "$subfolder"; then
            analyzed_count=$((analyzed_count + 1))
        fi
    done
    
    # Calculate and display grand totals
    if [[ $analyzed_count -gt 0 ]]; then
        local grand_meaningful=0
        local grand_non_empty=0
        local grand_csproj=0
        local grand_cs=0
        local grand_nuget=0
        local ratio_sum=0
        
        while IFS='|' read -r sf_meaningful sf_non_empty sf_csproj sf_cs sf_nuget sf_name; do
            grand_meaningful=$((grand_meaningful + sf_meaningful))
            grand_non_empty=$((grand_non_empty + sf_non_empty))
            grand_csproj=$((grand_csproj + sf_csproj))
            grand_cs=$((grand_cs + sf_cs))
            grand_nuget=$((grand_nuget + sf_nuget))
            
            if [[ $sf_non_empty -gt 0 ]]; then
                local sf_ratio=$(awk "BEGIN {printf \"%.2f\", ($sf_meaningful / $sf_non_empty) * 100}")
                ratio_sum=$(awk "BEGIN {printf \"%.2f\", $ratio_sum + $sf_ratio}")
            fi
        done < "$TEMP_DIR/grand_totals.txt"
        
        local grand_ratio="0.0"
        if [[ $grand_non_empty -gt 0 ]]; then
            grand_ratio=$(awk "BEGIN {printf \"%.2f\", ($grand_meaningful / $grand_non_empty) * 100}")
        fi
        
        local avg_ratio="0.0"
        if [[ $analyzed_count -gt 0 ]]; then
            avg_ratio=$(awk "BEGIN {printf \"%.2f\", $ratio_sum / $analyzed_count}")
        fi
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                       GRAND TOTALS                         ║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
        printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Analyzed subfolders:" "$analyzed_count"
        printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total projects (*.csproj):" "$grand_csproj"
        printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total C# files (*.cs):" "$grand_cs"
        printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total NuGet dependencies:" "$grand_nuget"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
        printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total non-empty lines:" "$grand_non_empty"
        printf "${CYAN}║${NC} %-40s ${GREEN}%15s${NC} ${CYAN}║${NC}\n" "Total meaningful lines:" "$grand_meaningful"
        printf "${CYAN}║${NC} %-40s ${GREEN}%14s%%${NC} ${CYAN}║${NC}\n" "Overall code ratio:" "$grand_ratio"
        printf "${CYAN}║${NC} %-40s ${GREEN}%14s%%${NC} ${CYAN}║${NC}\n" "Average ratio per repository:" "$avg_ratio"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}No .NET projects found in any subfolder.${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Analysis complete!${NC}"
}

main