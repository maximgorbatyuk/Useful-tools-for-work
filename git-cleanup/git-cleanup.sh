#!/bin/bash

# Git Branch Cleanup Script
# Options:
# 1. Delete merged branches (safe cleanup)
# 2. Delete stale branches (no activity for 6+ months)

set -e

# Protected branches that should never be deleted
PROTECTED_BRANCHES=("development" "sandbox" "production" "main" "master")

# Remote name (usually 'origin')
REMOTE="origin"

# Stale threshold in months
STALE_MONTHS=6

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   Git Branch Cleanup Script${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Fetch latest from remote
echo -e "${YELLOW}Fetching latest from remote...${NC}"
git fetch --all --prune
echo ""

# Step 1: Select cleanup mode
echo -e "${CYAN}Step 1: Select cleanup mode${NC}"
echo ""
echo -e "  ${YELLOW}1)${NC} Merged branches - Delete branches already merged into protected branches"
echo -e "  ${YELLOW}2)${NC} Stale branches - Delete branches with no activity for ${STALE_MONTHS}+ months"
echo ""

while true; do
    read -p "Select mode (1 or 2): " cleanup_mode
    
    case $cleanup_mode in
        1)
            echo -e "${GREEN}Mode: Merged branches cleanup${NC}"
            CLEANUP_TYPE="merged"
            break
            ;;
        2)
            echo -e "${GREEN}Mode: Stale branches cleanup (${STALE_MONTHS}+ months inactive)${NC}"
            CLEANUP_TYPE="stale"
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1 or 2${NC}"
            ;;
    esac
done
echo ""

# Step 2: Select dry run or proceed
echo -e "${CYAN}Step 2: Select action${NC}"
echo ""
echo -e "  ${YELLOW}1)${NC} Dry run - Show branches that would be deleted"
echo -e "  ${YELLOW}2)${NC} Proceed - Actually delete branches"
echo ""

while true; do
    read -p "Select action (1 or 2): " action_mode
    
    case $action_mode in
        1)
            DRY_RUN=true
            echo -e "${GREEN}Action: Dry run${NC}"
            break
            ;;
        2)
            DRY_RUN=false
            echo -e "${GREEN}Action: Proceed with deletion${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1 or 2${NC}"
            ;;
    esac
done
echo ""

# Function to check if branch is protected
is_protected() {
    local branch="$1"
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if branch is merged into any protected branch
is_merged_into_protected() {
    local branch_ref="$1"
    
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        # Check if protected branch exists on remote
        if git show-ref --verify --quiet "refs/remotes/$REMOTE/$protected" 2>/dev/null; then
            # Check if the branch is an ancestor of the protected branch
            if git merge-base --is-ancestor "$branch_ref" "$REMOTE/$protected" 2>/dev/null; then
                return 0
            fi
        fi
    done
    return 1
}

# Function to get last commit date of a branch (in seconds since epoch)
get_branch_last_activity() {
    local branch_ref="$1"
    git log -1 --format="%ct" "$branch_ref" 2>/dev/null || echo "0"
}

# Function to format date for display
format_date() {
    local timestamp="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        date -r "$timestamp" "+%Y-%m-%d" 2>/dev/null || echo "unknown"
    else
        # Linux
        date -d "@$timestamp" "+%Y-%m-%d" 2>/dev/null || echo "unknown"
    fi
}

# Function to calculate months ago
get_months_ago() {
    local timestamp="$1"
    local now=$(date +%s)
    local diff=$((now - timestamp))
    local months=$((diff / 2592000)) # 30 days in seconds
    echo "$months"
}

# Calculate stale threshold timestamp
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    STALE_THRESHOLD=$(date -v-${STALE_MONTHS}m +%s)
else
    # Linux
    STALE_THRESHOLD=$(date -d "${STALE_MONTHS} months ago" +%s)
fi

# Find existing protected branches
echo -e "${CYAN}Protected branches on remote:${NC}"
for protected in "${PROTECTED_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/remotes/$REMOTE/$protected" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $protected"
    fi
done
echo ""

# Get all remote branches
echo -e "${CYAN}Step 3: Analyzing remote branches...${NC}"
echo ""

branches_to_delete=()
kept_branches=()
protected_branches_found=()

while IFS= read -r branch_ref; do
    # Skip empty lines
    [[ -z "$branch_ref" ]] && continue
    
    # Remove 'origin/' prefix to get branch name
    branch_name="${branch_ref#$REMOTE/}"
    
    # Skip HEAD reference
    [[ "$branch_name" == "HEAD" ]] && continue
    [[ "$branch_ref" == *"HEAD"* ]] && continue
    
    # Skip protected branches
    if is_protected "$branch_name"; then
        echo -e "${GREEN}[PROTECTED]${NC} $branch_name - keeping"
        protected_branches_found+=("$branch_name")
        continue
    fi
    
    if [[ "$CLEANUP_TYPE" == "merged" ]]; then
        # Check if merged into any protected branch
        if is_merged_into_protected "refs/remotes/$branch_ref"; then
            echo -e "${YELLOW}[MERGED]${NC} $branch_name - marked for deletion"
            branches_to_delete+=("$branch_name")
        else
            echo -e "${CYAN}[UNMERGED]${NC} $branch_name - keeping (work in progress)"
            kept_branches+=("$branch_name")
        fi
    elif [[ "$CLEANUP_TYPE" == "stale" ]]; then
        # Check last activity
        last_activity=$(get_branch_last_activity "refs/remotes/$branch_ref")
        last_date=$(format_date "$last_activity")
        months_ago=$(get_months_ago "$last_activity")
        
        if [[ "$last_activity" -lt "$STALE_THRESHOLD" ]]; then
            echo -e "${YELLOW}[STALE]${NC} $branch_name - last activity: $last_date (${months_ago} months ago) - marked for deletion"
            branches_to_delete+=("$branch_name")
        else
            echo -e "${CYAN}[ACTIVE]${NC} $branch_name - last activity: $last_date (${months_ago} months ago) - keeping"
            kept_branches+=("$branch_name")
        fi
    fi
    
done < <(git branch -r --format='%(refname:short)' | grep "^$REMOTE/")

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Protected branches: ${#protected_branches_found[@]}${NC}"
echo -e "${CYAN}Kept branches: ${#kept_branches[@]}${NC}"
echo -e "${YELLOW}Branches to delete: ${#branches_to_delete[@]}${NC}"
echo -e "${CYAN}========================================${NC}"

if [ ${#branches_to_delete[@]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}No branches to delete.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Branches to delete:${NC}"
for branch in "${branches_to_delete[@]}"; do
    if [[ "$CLEANUP_TYPE" == "stale" ]]; then
        # Show last activity for stale branches
        branch_ref="$REMOTE/$branch"
        last_activity=$(get_branch_last_activity "refs/remotes/$branch_ref")
        last_date=$(format_date "$last_activity")
        months_ago=$(get_months_ago "$last_activity")
        echo -e "  - $branch ${MAGENTA}(last activity: $last_date, ${months_ago} months ago)${NC}"
    else
        echo -e "  - $branch"
    fi
done

# If dry run, exit here
if $DRY_RUN; then
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}   Dry run completed${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Cleanup type: ${YELLOW}$CLEANUP_TYPE${NC}"
    echo -e "Branches that would be deleted: ${YELLOW}${#branches_to_delete[@]}${NC}"
    echo ""
    echo -e "${YELLOW}Run script again and select 'Proceed' to delete these branches${NC}"
    exit 0
fi

# Confirm deletion
echo ""
read -p "Do you want to proceed with deletion? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting branches...${NC}"

deleted_count=0
failed_count=0

for branch in "${branches_to_delete[@]}"; do
    echo -e "Deleting: ${YELLOW}$branch${NC}"
    
    # Delete remote branch
    if git push "$REMOTE" --delete "$branch" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Remote branch deleted${NC}"
        ((deleted_count++))
        
        # Also delete local branch if it exists
        if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
            git branch -D "$branch" 2>/dev/null && \
                echo -e "  ${GREEN}✓ Local branch also deleted${NC}"
        fi
    else
        echo -e "  ${RED}✗ Failed to delete remote branch${NC}"
        ((failed_count++))
    fi
done

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}   Cleanup completed${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "Cleanup type: ${YELLOW}$CLEANUP_TYPE${NC}"
echo -e "${GREEN}Successfully deleted: $deleted_count${NC}"
if [[ $failed_count -gt 0 ]]; then
    echo -e "${RED}Failed to delete: $failed_count${NC}"
fi
echo ""