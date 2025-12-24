# Git Branch Cleanup

A bash script for macOS/Linux that automatically cleans up Git branches from both local and remote repositories.

## Features

- 🔍 **Two cleanup modes** - Clean merged branches or stale inactive branches
- 👀 **Dry run mode** - Preview branches before deletion
- 🛡️ **Branch protection** - Never deletes protected branches
- 📅 **Activity tracking** - Shows last commit date for stale branches
- 🧹 **Full cleanup** - Removes both remote and local copies
- ✅ **Interactive confirmation** - Asks before deleting
- 🎨 **Color-coded output** - Easy to read results

## Cleanup Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Merged branches** | Deletes branches already merged into protected branches | Safe routine cleanup |
| **Stale branches** | Deletes branches with no activity for 6+ months | Remove abandoned work |

## Branch Handling

| Branch Status | Merged Mode | Stale Mode |
|---------------|-------------|------------|
| **Protected** (`main`, `development`, etc.) | 🔒 Always keep | 🔒 Always keep |
| **Merged** into protected branch | ✂️ Delete | - |
| **Unmerged** | ✅ Keep | - |
| **Active** (recent commits) | - | ✅ Keep |
| **Stale** (6+ months inactive) | - | ✂️ Delete |

## Requirements

- macOS or Linux
- Bash 3.2+
- Git

## Installation
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/git-branch-cleanup.git

# Make the script executable
chmod +x git-cleanup.sh

# Optionally, move to your PATH for global access
cp git-cleanup.sh /usr/local/bin/git-cleanup
```

## Usage

Navigate to any Git repository and run:
```bash
./git-cleanup.sh
```

Or if installed globally:
```bash
git-cleanup
```

## Workflow
```
Step 1: Select cleanup mode
    ├── 1) Merged branches
    └── 2) Stale branches (6+ months)
            ↓
Step 2: Select action
    ├── 1) Dry run (preview)
    └── 2) Proceed (delete)
            ↓
Step 3: Analyze branches
            ↓
    [If Dry Run → Show results and exit]
            ↓
Step 4: Confirm and delete
```

## Protected Branches

The following branches are never deleted:

- `main`
- `master`
- `development`
- `sandbox`
- `production`

## Example Output

### Merged Branches - Dry Run
```
========================================
   Git Branch Cleanup Script
========================================

Fetching latest from remote...

Step 1: Select cleanup mode

  1) Merged branches - Delete branches already merged into protected branches
  2) Stale branches - Delete branches with no activity for 6+ months

Select mode (1 or 2): 1
Mode: Merged branches cleanup

Step 2: Select action

  1) Dry run - Show branches that would be deleted
  2) Proceed - Actually delete branches

Select action (1 or 2): 1
Action: Dry run

Protected branches on remote:
  ✓ main
  ✓ development

Step 3: Analyzing remote branches...

[PROTECTED] main - keeping
[PROTECTED] development - keeping
[MERGED] feature/user-auth - marked for deletion
[MERGED] feature/api-update - marked for deletion
[MERGED] bugfix/login-fix - marked for deletion
[UNMERGED] feature/new-dashboard - keeping (work in progress)
[UNMERGED] feature/experimental - keeping (work in progress)

========================================
Protected branches: 2
Kept branches: 2
Branches to delete: 3
========================================

Branches to delete:
  - feature/user-auth
  - feature/api-update
  - bugfix/login-fix

========================================
   Dry run completed
========================================

Cleanup type: merged
Branches that would be deleted: 3

Run script again and select 'Proceed' to delete these branches
```

### Stale Branches - Dry Run
```
========================================
   Git Branch Cleanup Script
========================================

Fetching latest from remote...

Step 1: Select cleanup mode

  1) Merged branches - Delete branches already merged into protected branches
  2) Stale branches - Delete branches with no activity for 6+ months

Select mode (1 or 2): 2
Mode: Stale branches cleanup (6+ months inactive)

Step 2: Select action

  1) Dry run - Show branches that would be deleted
  2) Proceed - Actually delete branches

Select action (1 or 2): 1
Action: Dry run

Protected branches on remote:
  ✓ main
  ✓ development

Step 3: Analyzing remote branches...

[PROTECTED] main - keeping
[PROTECTED] development - keeping
[STALE] feature/old-login - last activity: 2024-03-15 (9 months ago) - marked for deletion
[STALE] feature/legacy-api - last activity: 2024-01-20 (11 months ago) - marked for deletion
[STALE] experiment/abandoned - last activity: 2024-02-05 (10 months ago) - marked for deletion
[ACTIVE] feature/new-dashboard - last activity: 2024-11-01 (1 months ago) - keeping
[ACTIVE] feature/user-profile - last activity: 2024-12-10 (0 months ago) - keeping
[ACTIVE] bugfix/urgent-fix - last activity: 2024-12-20 (0 months ago) - keeping

========================================
Protected branches: 2
Kept branches: 3
Branches to delete: 3
========================================

Branches to delete:
  - feature/old-login (last activity: 2024-03-15, 9 months ago)
  - feature/legacy-api (last activity: 2024-01-20, 11 months ago)
  - experiment/abandoned (last activity: 2024-02-05, 10 months ago)

========================================
   Dry run completed
========================================

Cleanup type: stale
Branches that would be deleted: 3

Run script again and select 'Proceed' to delete these branches
```

### Merged Branches - Proceed
```
========================================
   Git Branch Cleanup Script
========================================

Fetching latest from remote...

Step 1: Select cleanup mode

  1) Merged branches - Delete branches already merged into protected branches
  2) Stale branches - Delete branches with no activity for 6+ months

Select mode (1 or 2): 1
Mode: Merged branches cleanup

Step 2: Select action

  1) Dry run - Show branches that would be deleted
  2) Proceed - Actually delete branches

Select action (1 or 2): 2
Action: Proceed with deletion

Protected branches on remote:
  ✓ main
  ✓ development

Step 3: Analyzing remote branches...

[PROTECTED] main - keeping
[PROTECTED] development - keeping
[MERGED] feature/user-auth - marked for deletion
[MERGED] feature/api-update - marked for deletion
[UNMERGED] feature/new-dashboard - keeping (work in progress)

========================================
Protected branches: 2
Kept branches: 1
Branches to delete: 2
========================================

Branches to delete:
  - feature/user-auth
  - feature/api-update

Do you want to proceed with deletion? (y/N): y

Deleting branches...
Deleting: feature/user-auth
  ✓ Remote branch deleted
  ✓ Local branch also deleted
Deleting: feature/api-update
  ✓ Remote branch deleted

========================================
   Cleanup completed
========================================

Cleanup type: merged
Successfully deleted: 2
```

### Stale Branches - Proceed
```
========================================
   Git Branch Cleanup Script
========================================

Fetching latest from remote...

Step 1: Select cleanup mode

  1) Merged branches - Delete branches already merged into protected branches
  2) Stale branches - Delete branches with no activity for 6+ months

Select mode (1 or 2): 2
Mode: Stale branches cleanup (6+ months inactive)

Step 2: Select action

  1) Dry run - Show branches that would be deleted
  2) Proceed - Actually delete branches

Select action (1 or 2): 2
Action: Proceed with deletion

Protected branches on remote:
  ✓ main
  ✓ development

Step 3: Analyzing remote branches...

[PROTECTED] main - keeping
[PROTECTED] development - keeping
[STALE] feature/old-login - last activity: 2024-03-15 (9 months ago) - marked for deletion
[STALE] feature/legacy-api - last activity: 2024-01-20 (11 months ago) - marked for deletion
[ACTIVE] feature/new-dashboard - last activity: 2024-11-01 (1 months ago) - keeping

========================================
Protected branches: 2
Kept branches: 1
Branches to delete: 2
========================================

Branches to delete:
  - feature/old-login (last activity: 2024-03-15, 9 months ago)
  - feature/legacy-api (last activity: 2024-01-20, 11 months ago)

Do you want to proceed with deletion? (y/N): y

Deleting branches...
Deleting: feature/old-login
  ✓ Remote branch deleted
  ✓ Local branch also deleted
Deleting: feature/legacy-api
  ✓ Remote branch deleted

========================================
   Cleanup completed
========================================

Cleanup type: stale
Successfully deleted: 2
```

### No Branches to Delete
```
========================================
   Git Branch Cleanup Script
========================================

Fetching latest from remote...

Step 1: Select cleanup mode

  1) Merged branches - Delete branches already merged into protected branches
  2) Stale branches - Delete branches with no activity for 6+ months

Select mode (1 or 2): 1
Mode: Merged branches cleanup

Step 2: Select action

  1) Dry run - Show branches that would be deleted
  2) Proceed - Actually delete branches

Select action (1 or 2): 1
Action: Dry run

Protected branches on remote:
  ✓ main
  ✓ development

Step 3: Analyzing remote branches...

[PROTECTED] main - keeping
[PROTECTED] development - keeping
[UNMERGED] feature/new-dashboard - keeping (work in progress)
[UNMERGED] feature/experimental - keeping (work in progress)

========================================
Protected branches: 2
Kept branches: 2
Branches to delete: 0
========================================

No branches to delete.
```

## Configuration

Edit the script to customize:
```bash
# Protected branches (line 11)
PROTECTED_BRANCHES=("development" "sandbox" "production" "main" "master")

# Remote name (line 14)
REMOTE="origin"

# Stale threshold in months (line 17)
STALE_MONTHS=6
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Not a git repository` | Run from inside a git repository |
| `Failed to delete remote branch` | Check push permissions |
| Protected branch in delete list | Add branch to `PROTECTED_BRANCHES` |
| Wrong stale threshold | Adjust `STALE_MONTHS` variable |
| Date calculation error | Ensure `date` command is available |

## Compatibility

- ✅ macOS (Bash 3.2+)
- ✅ Linux (Bash 4.0+)
- ✅ Git 2.0+

## Safety Features

1. **Protected branches** - Critical branches are never deleted
2. **Dry run mode** - Preview before deleting
3. **Confirmation prompt** - Must confirm before deletion
4. **Color-coded output** - Easy to identify branch status
5. **Stale activity display** - See exactly how old branches are

## License

MIT License
