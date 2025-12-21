#!/usr/bin/env bash
#
# TP.Tools NuGet Package Upgrade Script
# Upgrades all TP.Tools.* packages across all .csproj files
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Protected branches that require new branch creation
PROTECTED_BRANCHES=("main" "master" "dev" "development" "sandbox")

# NuGet package prefix to search for
NUGET_PREFIX="TP.Tools"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   TP.Tools NuGet Upgrade Script${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Check if dotnet is installed
if ! command -v dotnet &>/dev/null; then
    echo -e "${RED}Error: dotnet CLI is not installed${NC}"
    exit 1
fi

# Find all .csproj files
csproj_files=()
while IFS= read -r file; do
    csproj_files+=("$file")
done < <(find . -name "*.csproj" -type f 2>/dev/null)

if [ ${#csproj_files[@]} -eq 0 ]; then
    echo -e "${RED}Error: No .csproj files found${NC}"
    exit 1
fi

echo -e "${YELLOW}Found ${#csproj_files[@]} .csproj file(s)${NC}"
echo ""

# Step 1: Search for TP.Tools.* packages
echo -e "${CYAN}Step 1: Searching for ${NUGET_PREFIX}.* packages...${NC}"
echo ""

# Use temporary file to store unique packages (associative arrays need bash 4+)
packages_tmp=$(mktemp)
trap "rm -f $packages_tmp" EXIT

for csproj in "${csproj_files[@]}"; do
    # Extract package references matching TP.Tools.*
    while IFS= read -r line; do
        # Extract package name
        if [[ $line =~ Include=\"(${NUGET_PREFIX}\.[^\"]+)\" ]]; then
            package_name="${BASH_REMATCH[1]}"
            
            # Extract version
            version="unknown"
            if [[ $line =~ Version=\"([^\"]+)\" ]]; then
                version="${BASH_REMATCH[1]}"
            fi
            
            # Store package:version pair
            echo "$package_name:$version" >> "$packages_tmp"
        fi
    done < <(grep -E "PackageReference.*${NUGET_PREFIX}\." "$csproj" 2>/dev/null || true)
done

# Get unique packages
packages_list=()
while IFS= read -r pkg; do
    packages_list+=("$pkg")
done < <(cut -d':' -f1 "$packages_tmp" | sort -u)

if [ ${#packages_list[@]} -eq 0 ]; then
    echo -e "${RED}No ${NUGET_PREFIX}.* packages found in any .csproj file${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#packages_list[@]} unique ${NUGET_PREFIX}.* package(s):${NC}"
echo ""
for package in "${packages_list[@]}"; do
    # Get version for this package
    version=$(grep "^$package:" "$packages_tmp" | head -1 | cut -d':' -f2)
    echo -e "  ${YELLOW}•${NC} $package (current: $version)"
done
echo ""

# Step 2: Ask for upgrade version
echo -e "${CYAN}Step 2: Enter target version${NC}"
echo ""

version_pattern='^1\.0\.[0-9]+$'

while true; do
    read -p "Enter upgrade version (format: 1.0.****): " target_version
    
    if [[ $target_version =~ $version_pattern ]]; then
        echo -e "${GREEN}Version accepted: $target_version${NC}"
        break
    else
        echo -e "${RED}Invalid version format. Please use format: 1.0.**** (e.g., 1.0.123, 1.0.4567)${NC}"
    fi
done
echo ""

# Step 3: Check current branch and ask for new branch if needed
echo -e "${CYAN}Step 3: Checking git branch...${NC}"
echo ""

current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD)
echo -e "Current branch: ${YELLOW}$current_branch${NC}"

is_protected=false
for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$current_branch" == "$protected" ]]; then
        is_protected=true
        break
    fi
done

if $is_protected; then
    echo -e "${YELLOW}Warning: You are on a protected branch ($current_branch)${NC}"
    echo ""
    
    while true; do
        read -p "Enter new branch name to checkout: " new_branch
        
        if [[ -z "$new_branch" ]]; then
            echo -e "${RED}Branch name cannot be empty${NC}"
            continue
        fi
        
        if [[ "$new_branch" =~ [[:space:]] ]]; then
            echo -e "${RED}Branch name cannot contain spaces${NC}"
            continue
        fi
        
        # Check if branch already exists
        if git show-ref --verify --quiet "refs/heads/$new_branch" 2>/dev/null; then
            echo -e "${RED}Branch '$new_branch' already exists. Please choose a different name.${NC}"
            continue
        fi
        
        # Create and checkout new branch
        echo -e "Creating and switching to branch: ${GREEN}$new_branch${NC}"
        git checkout -b "$new_branch"
        current_branch="$new_branch"
        break
    done
else
    echo -e "${GREEN}Branch '$current_branch' is not protected. Continuing...${NC}"
fi
echo ""

# Step 4: Upgrade all packages
echo -e "${CYAN}Step 4: Upgrading packages to version $target_version...${NC}"
echo ""

upgrade_failed=false

for package in "${packages_list[@]}"; do
    echo -e "Upgrading ${YELLOW}$package${NC} to ${GREEN}$target_version${NC}..."
    
    for csproj in "${csproj_files[@]}"; do
        # Check if this csproj contains the package
        if grep -q "PackageReference.*Include=\"$package\"" "$csproj" 2>/dev/null; then
            # Use dotnet add package to upgrade
            if dotnet add "$csproj" package "$package" --version "$target_version" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Updated in $(basename "$csproj")"
            else
                echo -e "  ${RED}✗${NC} Failed to update in $(basename "$csproj")"
                upgrade_failed=true
            fi
        fi
    done
done

if $upgrade_failed; then
    echo ""
    echo -e "${RED}Some packages failed to upgrade. Please check the errors above.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All packages upgraded successfully!${NC}"
echo ""

# Step 5: Run dotnet build
echo -e "${CYAN}Step 5: Building solution...${NC}"
echo ""

if dotnet build; then
    echo ""
    echo -e "${GREEN}Build succeeded!${NC}"
else
    echo ""
    echo -e "${RED}Build failed! See errors above.${NC}"
    exit 1
fi

echo ""

# Step 6: Run dotnet test
echo -e "${CYAN}Step 6: Running tests...${NC}"
echo ""

test_output=$(mktemp)
trap "rm -f $packages_tmp $test_output" EXIT

if dotnet test 2>&1 | tee "$test_output"; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    echo ""
    echo -e "${YELLOW}Failed tests:${NC}"
    grep -iE "(failed|error)" "$test_output" | grep -v "0 Error" | head -20 || true
    exit 1
fi

echo ""

# Step 7: Git commit
echo -e "${CYAN}Step 7: Committing changes...${NC}"
echo ""

# Stage all .csproj files
git add "*.csproj" 2>/dev/null || find . -name "*.csproj" -exec git add {} \;

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo -e "${YELLOW}No changes to commit (packages might already be at target version)${NC}"
else
    git commit -m "Nugets upgraded"
    echo ""
    echo -e "${GREEN}Changes committed successfully!${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}   Upgrade completed successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "Branch: ${YELLOW}$current_branch${NC}"
echo -e "Version: ${YELLOW}$target_version${NC}"
echo -e "Packages upgraded: ${YELLOW}${#packages_list[@]}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review the changes: ${CYAN}git diff HEAD~1${NC}"
echo -e "  2. Push to remote: ${CYAN}git push -u origin $current_branch${NC}"
echo ""