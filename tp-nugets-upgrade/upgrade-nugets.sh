#!/usr/bin/env bash
#
# TP.Tools NuGet Package Upgrade Script
# Upgrades all TP.Tools.* packages across multiple .NET projects
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Protected branches that require new branch creation
PROTECTED_BRANCHES=("main" "master" "dev" "development" "sandbox")

# NuGet package prefix to search for
NUGET_PREFIX="TP.Tools"

# Root directory (current directory by default)
ROOT_DIR="$(pwd)"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   TP.Tools NuGet Upgrade Script${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "Root directory: ${YELLOW}$ROOT_DIR${NC}"
echo ""

# Check if dotnet is installed
if ! command -v dotnet &>/dev/null; then
    echo -e "${RED}Error: dotnet CLI is not installed${NC}"
    exit 1
fi

# Step 0: Ask for dry run or proceed
echo -e "${CYAN}Step 0: Select mode${NC}"
echo ""
echo -e "  ${YELLOW}1)${NC} Dry run - scan and show packages only"
echo -e "  ${YELLOW}2)${NC} Proceed - scan, upgrade, build, test, commit and push"
echo ""

while true; do
    read -p "Select mode (1 or 2): " mode_choice
    
    case $mode_choice in
        1)
            DRY_RUN=true
            echo -e "${GREEN}Mode: Dry run${NC}"
            break
            ;;
        2)
            DRY_RUN=false
            echo -e "${GREEN}Mode: Proceed with upgrade${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1 or 2${NC}"
            ;;
    esac
done
echo ""

# Find all project directories (directories containing .csproj files)
echo -e "${CYAN}Step 1: Scanning for .NET projects...${NC}"
echo ""

project_dirs=()
while IFS= read -r csproj; do
    dir=$(dirname "$csproj")
    # Get relative path from root
    rel_dir="${dir#$ROOT_DIR/}"
    project_dirs+=("$dir")
done < <(find "$ROOT_DIR" -name "*.csproj" -type f 2>/dev/null | sort -u)

# Get unique parent directories (solution/project roots)
solution_dirs=()
while IFS= read -r dir; do
    # Check if directory contains .sln or .csproj at root level
    if ls "$dir"/*.sln 1>/dev/null 2>&1 || ls "$dir"/*.csproj 1>/dev/null 2>&1; then
        solution_dirs+=("$dir")
    fi
done < <(find "$ROOT_DIR" -maxdepth 2 -type d 2>/dev/null | sort -u)

# If no solution dirs found, use directories containing csproj
if [ ${#solution_dirs[@]} -eq 0 ]; then
    # Get unique parent directories of csproj files
    while IFS= read -r dir; do
        solution_dirs+=("$dir")
    done < <(for d in "${project_dirs[@]}"; do dirname "$d"; done | sort -u)
fi

# Fallback to root if still empty
if [ ${#solution_dirs[@]} -eq 0 ]; then
    solution_dirs=("$ROOT_DIR")
fi

echo -e "${GREEN}Found ${#project_dirs[@]} .csproj file(s)${NC}"
echo ""

# Step 2: Scan all projects for TP.Tools.* packages
echo -e "${CYAN}Step 2: Scanning for ${NUGET_PREFIX}.* packages...${NC}"
echo ""

# Temporary files for storing results
packages_tmp=$(mktemp)
projects_with_packages_tmp=$(mktemp)
trap "rm -f $packages_tmp $projects_with_packages_tmp" EXIT

# Structure: project_dir|csproj_file|package_name|version
for csproj in $(find "$ROOT_DIR" -name "*.csproj" -type f 2>/dev/null); do
    project_dir=$(dirname "$csproj")
    rel_path="${csproj#$ROOT_DIR/}"
    
    while IFS= read -r line; do
        if [[ $line =~ Include=\"(${NUGET_PREFIX}\.[^\"]+)\" ]]; then
            package_name="${BASH_REMATCH[1]}"
            
            version="unknown"
            if [[ $line =~ Version=\"([^\"]+)\" ]]; then
                version="${BASH_REMATCH[1]}"
            fi
            
            echo "$project_dir|$rel_path|$package_name|$version" >> "$packages_tmp"
            echo "$project_dir" >> "$projects_with_packages_tmp"
        fi
    done < <(grep -E "PackageReference.*${NUGET_PREFIX}\." "$csproj" 2>/dev/null || true)
done

# Get unique projects with packages
projects_to_upgrade=()
while IFS= read -r dir; do
    projects_to_upgrade+=("$dir")
done < <(sort -u "$projects_with_packages_tmp" 2>/dev/null || true)

# Get unique packages
unique_packages=()
while IFS= read -r pkg; do
    unique_packages+=("$pkg")
done < <(cut -d'|' -f3 "$packages_tmp" | sort -u 2>/dev/null || true)

if [ ${#unique_packages[@]} -eq 0 ]; then
    echo -e "${RED}No ${NUGET_PREFIX}.* packages found in any project${NC}"
    exit 1
fi

# Display results
echo -e "${GREEN}Found ${#unique_packages[@]} unique ${NUGET_PREFIX}.* package(s)${NC}"
echo -e "${GREEN}Found ${#projects_to_upgrade[@]} project(s) with ${NUGET_PREFIX}.* packages${NC}"
echo ""

echo -e "${MAGENTA}── Packages Summary ──${NC}"
echo ""
for package in "${unique_packages[@]}"; do
    versions=$(grep "|$package|" "$packages_tmp" | cut -d'|' -f4 | sort -u | tr '\n' ', ' | sed 's/,$//')
    echo -e "  ${YELLOW}•${NC} $package (versions: $versions)"
done
echo ""

echo -e "${MAGENTA}── Projects with ${NUGET_PREFIX}.* packages ──${NC}"
echo ""
for project_dir in "${projects_to_upgrade[@]}"; do
    rel_dir="${project_dir#$ROOT_DIR/}"
    [ "$rel_dir" == "$project_dir" ] && rel_dir="."
    
    echo -e "  ${CYAN}📁 $rel_dir${NC}"
    
    # List packages in this project
    while IFS='|' read -r _ csproj pkg ver; do
        csproj_name=$(basename "$csproj")
        echo -e "      ${YELLOW}•${NC} $pkg ($ver) in $csproj_name"
    done < <(grep "^$project_dir|" "$packages_tmp")
    echo ""
done

# If dry run, exit here
if $DRY_RUN; then
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}   Dry run completed${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Total unique packages: ${YELLOW}${#unique_packages[@]}${NC}"
    echo -e "Total projects to upgrade: ${YELLOW}${#projects_to_upgrade[@]}${NC}"
    echo ""
    echo -e "${YELLOW}Run script again and select mode 2 to proceed with upgrade${NC}"
    exit 0
fi

# ===== PROCEED MODE STARTS HERE =====

# Step 3: Ask for upgrade version
echo -e "${CYAN}Step 3: Enter target version${NC}"
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

# Step 4: Check git status for each project
echo -e "${CYAN}Step 4: Checking git repositories...${NC}"
echo ""

# Track git repos we've processed
git_repos_tmp=$(mktemp)
trap "rm -f $packages_tmp $projects_with_packages_tmp $git_repos_tmp" EXIT

for project_dir in "${projects_to_upgrade[@]}"; do
    # Find git root for this project
    git_root=$(cd "$project_dir" && git rev-parse --show-toplevel 2>/dev/null || echo "")
    
    if [ -z "$git_root" ]; then
        echo -e "${YELLOW}Warning: $project_dir is not in a git repository${NC}"
        continue
    fi
    
    # Skip if we've already processed this repo
    if grep -q "^$git_root$" "$git_repos_tmp" 2>/dev/null; then
        continue
    fi
    echo "$git_root" >> "$git_repos_tmp"
    
    rel_git="${git_root#$ROOT_DIR/}"
    [ "$rel_git" == "$git_root" ] && rel_git="."
    
    echo -e "  ${CYAN}📂 Git repo: $rel_git${NC}"
    
    cd "$git_root"
    
    current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD)
    echo -e "     Branch: ${YELLOW}$current_branch${NC}"
    
    is_protected=false
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        if [[ "$current_branch" == "$protected" ]]; then
            is_protected=true
            break
        fi
    done
    
    if $is_protected; then
        echo -e "     ${YELLOW}Warning: Protected branch detected${NC}"
        
        while true; do
            read -p "     Enter new branch name for $rel_git: " new_branch
            
            if [[ -z "$new_branch" ]]; then
                echo -e "     ${RED}Branch name cannot be empty${NC}"
                continue
            fi
            
            if [[ "$new_branch" =~ [[:space:]] ]]; then
                echo -e "     ${RED}Branch name cannot contain spaces${NC}"
                continue
            fi
            
            if git show-ref --verify --quiet "refs/heads/$new_branch" 2>/dev/null; then
                echo -e "     ${RED}Branch '$new_branch' already exists${NC}"
                continue
            fi
            
            git checkout -b "$new_branch"
            echo -e "     ${GREEN}Created branch: $new_branch${NC}"
            break
        done
    fi
    echo ""
done

cd "$ROOT_DIR"

# Step 5: Upgrade packages in each project
echo -e "${CYAN}Step 5: Upgrading packages to version $target_version...${NC}"
echo ""

upgrade_failed=false

for project_dir in "${projects_to_upgrade[@]}"; do
    rel_dir="${project_dir#$ROOT_DIR/}"
    [ "$rel_dir" == "$project_dir" ] && rel_dir="."
    
    echo -e "${MAGENTA}── Upgrading: $rel_dir ──${NC}"
    
    # Get csproj files in this project directory
    while IFS='|' read -r _ csproj pkg _; do
        full_csproj="$ROOT_DIR/$csproj"
        csproj_name=$(basename "$csproj")
        
        echo -e "  Upgrading ${YELLOW}$pkg${NC} in $csproj_name..."
        
        if dotnet add "$full_csproj" package "$pkg" --version "$target_version" &>/dev/null; then
            echo -e "    ${GREEN}✓${NC} Success"
        else
            echo -e "    ${RED}✗${NC} Failed"
            upgrade_failed=true
        fi
    done < <(grep "^$project_dir|" "$packages_tmp" | sort -u -t'|' -k2,3)
    
    echo ""
done

if $upgrade_failed; then
    echo -e "${RED}Some packages failed to upgrade. Please check the errors above.${NC}"
    exit 1
fi

echo -e "${GREEN}All packages upgraded successfully!${NC}"
echo ""

# Step 6: Build each project
echo -e "${CYAN}Step 6: Building projects...${NC}"
echo ""

build_failed=false

for project_dir in "${projects_to_upgrade[@]}"; do
    rel_dir="${project_dir#$ROOT_DIR/}"
    [ "$rel_dir" == "$project_dir" ] && rel_dir="."
    
    echo -e "${MAGENTA}── Building: $rel_dir ──${NC}"
    
    cd "$project_dir"
    
    # Find solution file or use directory
    sln_file=$(ls *.sln 2>/dev/null | head -1 || echo "")
    
    if [ -n "$sln_file" ]; then
        build_target="$sln_file"
    else
        build_target="."
    fi
    
    if dotnet build "$build_target"; then
        echo -e "${GREEN}✓ Build succeeded${NC}"
    else
        echo -e "${RED}✗ Build failed${NC}"
        build_failed=true
    fi
    echo ""
done

cd "$ROOT_DIR"

if $build_failed; then
    echo -e "${RED}Some projects failed to build. Please fix errors before continuing.${NC}"
    exit 1
fi

echo -e "${GREEN}All projects built successfully!${NC}"
echo ""

# Step 7: Test each project
echo -e "${CYAN}Step 7: Running tests...${NC}"
echo ""

test_failed=false
test_output=$(mktemp)
trap "rm -f $packages_tmp $projects_with_packages_tmp $git_repos_tmp $test_output" EXIT

for project_dir in "${projects_to_upgrade[@]}"; do
    rel_dir="${project_dir#$ROOT_DIR/}"
    [ "$rel_dir" == "$project_dir" ] && rel_dir="."
    
    echo -e "${MAGENTA}── Testing: $rel_dir ──${NC}"
    
    cd "$project_dir"
    
    # Find solution file or use directory
    sln_file=$(ls *.sln 2>/dev/null | head -1 || echo "")
    
    if [ -n "$sln_file" ]; then
        test_target="$sln_file"
    else
        test_target="."
    fi
    
    if dotnet test "$test_target" 2>&1 | tee "$test_output"; then
        echo -e "${GREEN}✓ Tests passed${NC}"
    else
        echo -e "${RED}✗ Tests failed${NC}"
        echo ""
        echo -e "${YELLOW}Failed tests:${NC}"
        grep -iE "(failed|error)" "$test_output" | grep -v "0 Error" | head -20 || true
        test_failed=true
    fi
    echo ""
done

cd "$ROOT_DIR"

if $test_failed; then
    echo -e "${RED}Some tests failed. Please fix failing tests before continuing.${NC}"
    exit 1
fi

echo -e "${GREEN}All tests passed!${NC}"
echo ""

# Step 8: Commit and push changes
echo -e "${CYAN}Step 8: Committing and pushing changes...${NC}"
echo ""

# Process each git repo
while IFS= read -r git_root; do
    rel_git="${git_root#$ROOT_DIR/}"
    [ "$rel_git" == "$git_root" ] && rel_git="."
    
    echo -e "${MAGENTA}── Git repo: $rel_git ──${NC}"
    
    cd "$git_root"
    
    # Stage all .csproj files
    find . -name "*.csproj" -exec git add {} \; 2>/dev/null || true
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        echo -e "${YELLOW}No changes to commit${NC}"
    else
        git commit -m "Nugets upgraded to version $target_version"
        echo -e "${GREEN}✓ Changes committed${NC}"
        
        # Push changes
        current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD)
        
        echo -e "Pushing to origin/$current_branch..."
        if git push -u origin "$current_branch" 2>&1; then
            echo -e "${GREEN}✓ Pushed successfully${NC}"
        else
            echo -e "${RED}✗ Push failed. You may need to push manually.${NC}"
        fi
    fi
    echo ""
done < "$git_repos_tmp"

cd "$ROOT_DIR"

# Final summary
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}   Upgrade completed successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "Target version: ${YELLOW}$target_version${NC}"
echo -e "Packages upgraded: ${YELLOW}${#unique_packages[@]}${NC}"
echo -e "Projects upgraded: ${YELLOW}${#projects_to_upgrade[@]}${NC}"
echo ""
echo -e "${YELLOW}Upgraded packages:${NC}"
for package in "${unique_packages[@]}"; do
    echo -e "  • $package"
done
echo ""