#!/usr/bin/env bash
#
# Git Cleanup Manager Script
# Manages git-cleanup.sh across multiple repositories
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script name to manage
CLEANUP_SCRIPT="git-cleanup.sh"

# Root directory (current directory by default)
ROOT_DIR="$(pwd)"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Git Cleanup Manager${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "Root directory: ${YELLOW}$ROOT_DIR${NC}"
echo ""

# Check if git-cleanup.sh exists in the script directory
if [[ ! -f "$SCRIPT_DIR/$CLEANUP_SCRIPT" ]]; then
    echo -e "${RED}Error: $CLEANUP_SCRIPT not found in $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}Please place $CLEANUP_SCRIPT in the same directory as this script${NC}"
    exit 1
fi

# Function to find all subfolders that are git repositories
find_git_repos() {
    local repos=()
    while IFS= read -r dir; do
        # Check if it's a git repository
        if [[ -d "$dir/.git" ]]; then
            repos+=("$dir")
        fi
    done < <(find "$ROOT_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." 2>/dev/null | sort)
    
    echo "${repos[@]}"
}

# Function to check if subfolder has git-cleanup.sh
has_cleanup_script() {
    local folder="$1"
    [[ -f "$folder/$CLEANUP_SCRIPT" ]]
}

# Function to display folder list with status
display_folders_with_status() {
    local show_script_status="$1"
    local repos=()
    
    # Get git repositories
    while IFS= read -r repo; do
        [[ -n "$repo" ]] && repos+=("$repo")
    done < <(find "$ROOT_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." 2>/dev/null | sort)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${RED}No subfolders found${NC}"
        return 1
    fi
    
    echo ""
    local index=1
    for folder in "${repos[@]}"; do
        local folder_name=$(basename "$folder")
        local is_git=""
        local has_script=""
        
        # Check if git repo
        if [[ -d "$folder/.git" ]]; then
            is_git="${GREEN}[git]${NC}"
        else
            is_git="${YELLOW}[not git]${NC}"
        fi
        
        # Check for cleanup script
        if [[ "$show_script_status" == "true" ]]; then
            if has_cleanup_script "$folder"; then
                has_script="${GREEN}[has $CLEANUP_SCRIPT]${NC}"
            else
                has_script="${RED}[no $CLEANUP_SCRIPT]${NC}"
            fi
        fi
        
        echo -e "  ${YELLOW}$index)${NC} $folder_name $is_git $has_script"
        ((index++))
    done
    
    echo ""
    return 0
}

# Function to get folder by index
get_folder_by_index() {
    local index="$1"
    local repos=()
    
    while IFS= read -r repo; do
        [[ -n "$repo" ]] && repos+=("$repo")
    done < <(find "$ROOT_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." 2>/dev/null | sort)
    
    if [[ $index -ge 1 && $index -le ${#repos[@]} ]]; then
        echo "${repos[$((index-1))]}"
    else
        echo ""
    fi
}

# Function to get folder count
get_folder_count() {
    find "$ROOT_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." 2>/dev/null | wc -l | tr -d ' '
}

# Feature 1: Copy script to subfolder
feature_copy_script() {
    echo -e "${CYAN}── Feature: Copy $CLEANUP_SCRIPT to subfolder ──${NC}"
    echo ""
    echo -e "Subfolders status:"
    
    if ! display_folders_with_status "true"; then
        return
    fi
    
    local folder_count=$(get_folder_count)
    
    while true; do
        echo -e "  ${YELLOW}0)${NC} Back to main menu"
        echo ""
        read -p "Select folder to copy script to (0-$folder_count): " choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        # Validate input
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid input. Please enter a number.${NC}"
            continue
        fi
        
        local selected_folder=$(get_folder_by_index "$choice")
        
        if [[ -z "$selected_folder" ]]; then
            echo -e "${RED}Invalid selection. Please try again.${NC}"
            continue
        fi
        
        local folder_name=$(basename "$selected_folder")
        
        # Check if script already exists
        if has_cleanup_script "$selected_folder"; then
            echo ""
            echo -e "${YELLOW}Warning: $CLEANUP_SCRIPT already exists in $folder_name${NC}"
            read -p "Overwrite? (y/N): " overwrite
            
            if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
                echo -e "Skipped."
                echo ""
                display_folders_with_status "true"
                continue
            fi
        fi
        
        # Copy the script
        echo ""
        echo -e "Copying $CLEANUP_SCRIPT to $folder_name..."
        
        if cp "$SCRIPT_DIR/$CLEANUP_SCRIPT" "$selected_folder/$CLEANUP_SCRIPT"; then
            chmod +x "$selected_folder/$CLEANUP_SCRIPT"
            echo -e "${GREEN}✓ Script copied successfully${NC}"
            echo -e "${GREEN}✓ Made executable${NC}"
        else
            echo -e "${RED}✗ Failed to copy script${NC}"
        fi
        
        echo ""
        
        # Ask if user wants to copy to another folder
        read -p "Copy to another folder? (y/N): " continue_copy
        
        if [[ "$continue_copy" != "y" && "$continue_copy" != "Y" ]]; then
            return
        fi
        
        echo ""
        display_folders_with_status "true"
    done
}

# Feature 2: Run script in subfolder
feature_run_script() {
    echo -e "${CYAN}── Feature: Run $CLEANUP_SCRIPT in subfolder ──${NC}"
    echo ""
    echo -e "Subfolders status:"
    
    if ! display_folders_with_status "true"; then
        return
    fi
    
    local folder_count=$(get_folder_count)
    
    while true; do
        echo -e "  ${YELLOW}0)${NC} Back to main menu"
        echo ""
        read -p "Select folder to run script in (0-$folder_count): " choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        # Validate input
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid input. Please enter a number.${NC}"
            continue
        fi
        
        local selected_folder=$(get_folder_by_index "$choice")
        
        if [[ -z "$selected_folder" ]]; then
            echo -e "${RED}Invalid selection. Please try again.${NC}"
            continue
        fi
        
        local folder_name=$(basename "$selected_folder")
        
        # Check if script exists
        if ! has_cleanup_script "$selected_folder"; then
            echo ""
            echo -e "${RED}Error: $CLEANUP_SCRIPT not found in $folder_name${NC}"
            echo -e "${YELLOW}Use Feature 1 to copy the script first${NC}"
            echo ""
            continue
        fi
        
        # Check if it's a git repository
        if [[ ! -d "$selected_folder/.git" ]]; then
            echo ""
            echo -e "${RED}Error: $folder_name is not a git repository${NC}"
            echo ""
            continue
        fi
        
        # Run the script
        echo ""
        echo -e "${MAGENTA}════════════════════════════════════════${NC}"
        echo -e "${MAGENTA}   Running $CLEANUP_SCRIPT in $folder_name${NC}"
        echo -e "${MAGENTA}════════════════════════════════════════${NC}"
        echo ""
        
        # Change to the folder and run the script
        (
            cd "$selected_folder"
            bash "./$CLEANUP_SCRIPT"
        )
        
        local exit_code=$?
        
        echo ""
        echo -e "${MAGENTA}════════════════════════════════════════${NC}"
        
        if [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}   Script completed successfully${NC}"
        else
            echo -e "${RED}   Script exited with code: $exit_code${NC}"
        fi
        
        echo -e "${MAGENTA}════════════════════════════════════════${NC}"
        echo ""
        
        # Ask if user wants to run in another folder
        read -p "Run in another folder? (y/N): " continue_run
        
        if [[ "$continue_run" != "y" && "$continue_run" != "Y" ]]; then
            return
        fi
        
        echo ""
        display_folders_with_status "true"
    done
}

# Feature 3: Copy script to all folders
feature_copy_to_all() {
    echo -e "${CYAN}── Feature: Copy $CLEANUP_SCRIPT to all git repositories ──${NC}"
    echo ""
    
    local repos=()
    while IFS= read -r dir; do
        [[ -n "$dir" ]] && [[ -d "$dir/.git" ]] && repos+=("$dir")
    done < <(find "$ROOT_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." 2>/dev/null | sort)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${RED}No git repositories found${NC}"
        return
    fi
    
    echo -e "Found ${GREEN}${#repos[@]}${NC} git repositories:"
    echo ""
    
    for repo in "${repos[@]}"; do
        local folder_name=$(basename "$repo")
        if has_cleanup_script "$repo"; then
            echo -e "  ${YELLOW}•${NC} $folder_name ${GREEN}[has script]${NC}"
        else
            echo -e "  ${YELLOW}•${NC} $folder_name ${RED}[no script]${NC}"
        fi
    done
    
    echo ""
    read -p "Copy $CLEANUP_SCRIPT to all repositories? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        return
    fi
    
    echo ""
    local copied=0
    local skipped=0
    local failed=0
    
    for repo in "${repos[@]}"; do
        local folder_name=$(basename "$repo")
        
        if has_cleanup_script "$repo"; then
            echo -e "  ${YELLOW}⊘${NC} $folder_name - skipped (already has script)"
            ((skipped++))
        elif cp "$SCRIPT_DIR/$CLEANUP_SCRIPT" "$repo/$CLEANUP_SCRIPT" 2>/dev/null; then
            chmod +x "$repo/$CLEANUP_SCRIPT"
            echo -e "  ${GREEN}✓${NC} $folder_name - copied"
            ((copied++))
        else
            echo -e "  ${RED}✗${NC} $folder_name - failed"
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${GREEN}Copied: $copied${NC} | ${YELLOW}Skipped: $skipped${NC} | ${RED}Failed: $failed${NC}"
}

# Feature 4: Remove script from subfolder
feature_remove_script() {
    echo -e "${CYAN}── Feature: Remove $CLEANUP_SCRIPT from subfolder ──${NC}"
    echo ""
    echo -e "Subfolders with $CLEANUP_SCRIPT:"
    
    local repos_with_script=()
    local index=1
    
    while IFS= read -r dir; do
        if [[ -n "$dir" ]] && has_cleanup_script "$dir"; then
            repos_with_script+=("$dir")
            local folder_name=$(basename "$dir")
            echo -e "  ${YELLOW}$index)${NC} $folder_name"
            ((index++))
        fi
    done < <(find "$ROOT_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." 2>/dev/null | sort)
    
    if [[ ${#repos_with_script[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No subfolders have $CLEANUP_SCRIPT${NC}"
        return
    fi
    
    echo ""
    echo -e "  ${YELLOW}0)${NC} Back to main menu"
    echo ""
    
    read -p "Select folder to remove script from (0-${#repos_with_script[@]}): " choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#repos_with_script[@]} ]]; then
        echo -e "${RED}Invalid selection${NC}"
        return
    fi
    
    local selected_folder="${repos_with_script[$((choice-1))]}"
    local folder_name=$(basename "$selected_folder")
    
    echo ""
    read -p "Remove $CLEANUP_SCRIPT from $folder_name? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        return
    fi
    
    if rm "$selected_folder/$CLEANUP_SCRIPT" 2>/dev/null; then
        echo -e "${GREEN}✓ Script removed from $folder_name${NC}"
    else
        echo -e "${RED}✗ Failed to remove script${NC}"
    fi
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}   Main Menu${NC}"
        echo -e "${CYAN}========================================${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} Copy $CLEANUP_SCRIPT to a subfolder"
        echo -e "  ${YELLOW}2)${NC} Run $CLEANUP_SCRIPT in a subfolder"
        echo -e "  ${YELLOW}3)${NC} Copy $CLEANUP_SCRIPT to all git repositories"
        echo -e "  ${YELLOW}4)${NC} Remove $CLEANUP_SCRIPT from a subfolder"
        echo -e "  ${YELLOW}0)${NC} Exit"
        echo ""
        
        read -p "Select option (0-4): " menu_choice
        
        case $menu_choice in
            1)
                echo ""
                feature_copy_script
                ;;
            2)
                echo ""
                feature_run_script
                ;;
            3)
                echo ""
                feature_copy_to_all
                ;;
            4)
                echo ""
                feature_remove_script
                ;;
            0)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
    done
}

# Run main menu
main_menu
```

## Features

| Feature | Description |
|---------|-------------|
| **Copy to subfolder** | Copy git-cleanup.sh to a selected repository |
| **Run in subfolder** | Execute git-cleanup.sh in a selected repository |
| **Copy to all** | Copy git-cleanup.sh to all git repositories at once |
| **Remove from subfolder** | Remove git-cleanup.sh from a selected repository |

## Directory Structure
```
/projects                      ← Run script here
├── git-cleanup-manager.sh     ← This manager script
├── git-cleanup.sh             ← The cleanup script to distribute
├── api-service/
│   ├── .git/
│   └── git-cleanup.sh         ← Copied here
├── worker-service/
│   ├── .git/
│   └── git-cleanup.sh         ← Copied here
└── shared-lib/
    ├── .git/
    └── (no script yet)