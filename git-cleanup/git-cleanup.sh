#!/bin/bash

# Git Branch Cleanup Script
# Finds and deletes ALL remote branches that ARE MERGED into protected branches

set -e

# Protected branches that should never be deleted
PROTECTED_BRANCHES=("development" "sandbox" "production" "main" "master")

# Remote name (usually 'origin')
REMOTE="origin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Fetch latest from remote
echo -e "${YELLOW}Fetching latest from remote...${NC}"
git fetch --all --prune

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

# Find existing protected branches
echo -e "${CYAN}Protected branches on remote:${NC}"
for protected in "${PROTECTED_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/remotes/$REMOTE/$protected" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $protected"
    fi
done
echo ""

# Get all remote branches
echo -e "${YELLOW}Analyzing remote branches...${NC}"
echo ""

branches_to_delete=()
unmerged_branches=()
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
    
    # Check if merged into any protected branch
    if is_merged_into_protected "refs/remotes/$branch_ref"; then
        echo -e "${YELLOW}[MERGED]${NC} $branch_name - marked for deletion"
        branches_to_delete+=("$branch_name")
        continue
    fi
    
    # Branch is not merged - keep it (someone might be working on it)
    echo -e "${CYAN}[UNMERGED]${NC} $branch_name - keeping (work in progress)"
    unmerged_branches+=("$branch_name")
    
done < <(git branch -r --format='%(refname:short)' | grep "^$REMOTE/")

echo ""
echo "=========================================="
echo -e "${GREEN}Protected branches: ${#protected_branches_found[@]}${NC}"
echo -e "${CYAN}Unmerged branches (kept): ${#unmerged_branches[@]}${NC}"
echo -e "${YELLOW}Merged branches (to delete): ${#branches_to_delete[@]}${NC}"
echo "=========================================="

if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
    echo -e "${GREEN}No branches to delete.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Branches to delete:${NC}"
for branch in "${branches_to_delete[@]}"; do
    echo "  - $branch"
done

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
            git branch -d "$branch" 2>/dev/null && \
                echo -e "  ${GREEN}✓ Local branch also deleted${NC}"
        fi
    else
        echo -e "  ${RED}✗ Failed to delete remote branch${NC}"
        ((failed_count++))
    fi
done

echo ""
echo "=========================================="
echo -e "${GREEN}Successfully deleted: $deleted_count${NC}"
if [[ $failed_count -gt 0 ]]; then
    echo -e "${RED}Failed to delete: $failed_count${NC}"
fi
echo -e "${GREEN}Cleanup complete!${NC}"