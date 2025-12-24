# Git Cleanup Manager

A bash script that manages the distribution and execution of `git-cleanup.sh` across multiple Git repositories.

## Features

- 📋 **Status overview** - See which repositories have the cleanup script installed
- 📁 **Copy to subfolder** - Deploy cleanup script to individual repositories
- 📦 **Copy to all** - Deploy cleanup script to all repositories at once
- ▶️ **Run in subfolder** - Execute cleanup script in selected repository
- 🗑️ **Remove script** - Remove cleanup script from repositories
- 🔄 **Sequential execution** - Run cleanup in multiple repositories one after another

## Requirements

- macOS or Linux
- Bash 3.2+
- Git
- `git-cleanup.sh` in the same directory

## Installation
```bash
# Place both scripts in your projects root directory
cp git-cleanup-manager.sh /path/to/your/projects/
cp git-cleanup.sh /path/to/your/projects/

# Make executable
chmod +x git-cleanup-manager.sh
chmod +x git-cleanup.sh
```

## Directory Structure
```
/projects                      ← Run manager here
├── git-cleanup-manager.sh     ← Manager script
├── git-cleanup.sh             ← Cleanup script to distribute
├── api-service/
│   ├── .git/
│   └── git-cleanup.sh         ← Distributed copy
├── worker-service/
│   ├── .git/
│   └── git-cleanup.sh         ← Distributed copy
├── shared-lib/
│   ├── .git/
│   └── (no script yet)
└── docs/
    └── (not a git repo)
```

## Usage

Run from the parent directory containing your repositories:
```bash
cd /path/to/projects
./git-cleanup-manager.sh
```

## Menu Options

| Option | Description |
|--------|-------------|
| **1** | Copy `git-cleanup.sh` to a selected subfolder |
| **2** | Run `git-cleanup.sh` in a selected subfolder |
| **3** | Copy `git-cleanup.sh` to all git repositories |
| **4** | Remove `git-cleanup.sh` from a selected subfolder |
| **0** | Exit |

## Workflow
```
┌─────────────────────────────────────┐
│           Main Menu                 │
├─────────────────────────────────────┤
│  1) Copy to subfolder               │
│  2) Run in subfolder                │
│  3) Copy to all repositories        │
│  4) Remove from subfolder           │
│  0) Exit                            │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│      Subfolder Selection            │
├─────────────────────────────────────┤
│  Shows status:                      │
│  • [git] / [not git]                │
│  • [has script] / [no script]       │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│      Action Execution               │
├─────────────────────────────────────┤
│  Copy / Run / Remove                │
└─────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│      Continue Prompt                │
├─────────────────────────────────────┤
│  Process another folder? (y/N)      │
└─────────────────────────────────────┘
```

## Example Output

### Main Menu
```
========================================
   Git Cleanup Manager
========================================

Root directory: /Users/dev/projects

========================================
   Main Menu
========================================

  1) Copy git-cleanup.sh to a subfolder
  2) Run git-cleanup.sh in a subfolder
  3) Copy git-cleanup.sh to all git repositories
  4) Remove git-cleanup.sh from a subfolder
  0) Exit

Select option (0-4):
```

### Feature 1: Copy Script to Subfolder
```
── Feature: Copy git-cleanup.sh to subfolder ──

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) worker-service [git] [no git-cleanup.sh]
  3) shared-lib [git] [no git-cleanup.sh]
  4) docs [not git] [no git-cleanup.sh]

  0) Back to main menu

Select folder to copy script to (0-4): 2

Copying git-cleanup.sh to worker-service...
✓ Script copied successfully
✓ Made executable

Copy to another folder? (y/N): y

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) worker-service [git] [has git-cleanup.sh]
  3) shared-lib [git] [no git-cleanup.sh]
  4) docs [not git] [no git-cleanup.sh]

  0) Back to main menu

Select folder to copy script to (0-4): 3

Copying git-cleanup.sh to shared-lib...
✓ Script copied successfully
✓ Made executable

Copy to another folder? (y/N): n
```

### Feature 1: Overwrite Existing Script
```
── Feature: Copy git-cleanup.sh to subfolder ──

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) worker-service [git] [has git-cleanup.sh]
  3) shared-lib [git] [no git-cleanup.sh]

  0) Back to main menu

Select folder to copy script to (0-3): 1

Warning: git-cleanup.sh already exists in api-service
Overwrite? (y/N): y

Copying git-cleanup.sh to api-service...
✓ Script copied successfully
✓ Made executable

Copy to another folder? (y/N):
```

### Feature 2: Run Script in Subfolder
```
── Feature: Run git-cleanup.sh in subfolder ──

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) worker-service [git] [has git-cleanup.sh]
  3) shared-lib [git] [no git-cleanup.sh]

  0) Back to main menu

Select folder to run script in (0-3): 1

════════════════════════════════════════
   Running git-cleanup.sh in api-service
════════════════════════════════════════

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
[MERGED] feature/old-feature - marked for deletion
[UNMERGED] feature/new-work - keeping (work in progress)

========================================
Protected branches: 2
Kept branches: 1
Branches to delete: 1
========================================

Branches to delete:
  - feature/old-feature

========================================
   Dry run completed
========================================

Cleanup type: merged
Branches that would be deleted: 1

Run script again and select 'Proceed' to delete these branches

════════════════════════════════════════
   Script completed successfully
════════════════════════════════════════

Run in another folder? (y/N): y

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) worker-service [git] [has git-cleanup.sh]
  3) shared-lib [git] [no git-cleanup.sh]

  0) Back to main menu

Select folder to run script in (0-3): 2

════════════════════════════════════════
   Running git-cleanup.sh in worker-service
════════════════════════════════════════

...
```

### Feature 2: Error - No Script
```
── Feature: Run git-cleanup.sh in subfolder ──

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) worker-service [git] [no git-cleanup.sh]
  3) shared-lib [git] [no git-cleanup.sh]

  0) Back to main menu

Select folder to run script in (0-3): 2

Error: git-cleanup.sh not found in worker-service
Use Feature 1 to copy the script first
```

### Feature 2: Error - Not a Git Repository
```
── Feature: Run git-cleanup.sh in subfolder ──

Subfolders status:

  1) api-service [git] [has git-cleanup.sh]
  2) docs [not git] [has git-cleanup.sh]

  0) Back to main menu

Select folder to run script in (0-2): 2

Error: docs is not a git repository
```

### Feature 3: Copy to All Repositories
```
── Feature: Copy git-cleanup.sh to all git repositories ──

Found 4 git repositories:

  • api-service [has script]
  • worker-service [no script]
  • shared-lib [no script]
  • auth-service [no script]

Copy git-cleanup.sh to all repositories? (y/N): y

  ⊘ api-service - skipped (already has script)
  ✓ worker-service - copied
  ✓ shared-lib - copied
  ✓ auth-service - copied

Copied: 3 | Skipped: 1 | Failed: 0
```

### Feature 4: Remove Script from Subfolder
```
── Feature: Remove git-cleanup.sh from subfolder ──

Subfolders with git-cleanup.sh:

  1) api-service
  2) worker-service
  3) shared-lib

  0) Back to main menu

Select folder to remove script from (0-3): 2

Remove git-cleanup.sh from worker-service? (y/N): y
✓ Script removed from worker-service
```

### Feature 4: No Scripts to Remove
```
── Feature: Remove git-cleanup.sh from subfolder ──

Subfolders with git-cleanup.sh:
No subfolders have git-cleanup.sh
```

## Status Indicators

| Indicator | Meaning |
|-----------|---------|
| `[git]` | Directory is a git repository |
| `[not git]` | Directory is not a git repository |
| `[has git-cleanup.sh]` | Cleanup script is installed |
| `[no git-cleanup.sh]` | Cleanup script is not installed |
| `✓` | Action succeeded |
| `✗` | Action failed |
| `⊘` | Action skipped |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `git-cleanup.sh not found` | Place `git-cleanup.sh` in the same directory as the manager |
| `No subfolders found` | Run from parent directory containing repositories |
| `Not a git repository` | Selected folder doesn't have `.git` directory |
| `Failed to copy script` | Check write permissions |
| Script execution fails | Check `git-cleanup.sh` for errors |

## Compatibility

- ✅ macOS (Bash 3.2+)
- ✅ Linux (Bash 4.0+)
- ✅ Git 2.0+

## Related Scripts

- [git-cleanup.sh](./README-git-cleanup.md) - The branch cleanup script that this manager distributes

## License

MIT License