# TP.Tools NuGet Upgrade Script

A bash script that automates upgrading all `TP.Tools.*` NuGet packages across multiple .NET projects and repositories.

## Features

- 🔍 **Auto-discovery** - Recursively finds all `TP.Tools.*` packages across all `.csproj` files
- 📂 **Folder selection** - Choose specific subfolder or process all at once
- 👀 **Dry run mode** - Preview packages and projects before making changes
- 📁 **Multi-project support** - Handles multiple .NET solutions in subdirectories
- 🗂️ **Multi-repo support** - Works with multiple git repositories
- ✅ **Version validation** - Ensures version follows `1.0.****` pattern
- 🛡️ **Branch protection** - Prompts for new branch when on protected branches
- 🔨 **Build verification** - Runs `dotnet build` and stops on failure
- 🧪 **Test verification** - Runs `dotnet test` and reports failures
- 📝 **Auto-commit** - Commits changes with version in message
- 🚀 **Auto-push** - Pushes changes to remote after commit

## Requirements

- macOS or Linux
- Bash 3.2+
- .NET SDK (`dotnet` CLI)
- Git

## Installation
```bash
# Copy script to your projects root directory
cp upgrade-nugets.sh /path/to/your/projects/

# Make executable
chmod +x upgrade-nugets.sh
```

## Usage

Run from the root directory containing your .NET projects:
```bash
cd /path/to/projects
./upgrade-nugets.sh
```

## Workflow
```
Step 1: Scan for .NET projects
    ↓
Step 2: Select folder (All / specific subfolder)
    ↓
Step 3: Select mode (Dry run / Proceed)
    ↓
Step 4: Scan for packages
    ↓
[If Dry Run → Exit]
    ↓
Step 5: Enter version
    ↓
Step 6: Check git branches
    ↓
Step 7: Upgrade packages
    ↓
Step 8: Build
    ↓
Step 9: Test
    ↓
Step 10: Commit & Push
```

## Workflow Steps

| Step | Action | On Failure |
|------|--------|------------|
| 1 | Scan directories for `.csproj` files | Exit if none found |
| 2 | Select folder to process | Must select valid option |
| 3 | Select mode (dry run / proceed) | Must select 1 or 2 |
| 4 | Find all `TP.Tools.*` packages | Exit if none found |
| 5 | Prompt for target version (`1.0.****`) | Re-prompt until valid |
| 6 | Check branches, prompt for new if protected | Must provide valid name |
| 7 | Upgrade all packages via `dotnet add package` | Exit on error |
| 8 | Run `dotnet build` for each project | Show errors and exit |
| 9 | Run `dotnet test` for each project | Show failed tests and exit |
| 10 | Commit and push changes | Report push failures |

## Modes

| Mode | Description |
|------|-------------|
| **Dry run** | Scans and displays all packages without making changes |
| **Proceed** | Full upgrade: scan → upgrade → build → test → commit → push |

## Directory Structure Example
```
/projects                      ← Run script here
├── upgrade-nugets.sh
├── api-service/
│   ├── .git/
│   ├── Api.sln
│   ├── src/
│   │   ├── Api/
│   │   │   └── Api.csproj
│   │   └── Api.Core/
│   │       └── Api.Core.csproj
│   └── tests/
│       └── Api.Tests/
│           └── Api.Tests.csproj
├── worker-service/
│   ├── .git/
│   ├── Worker.sln
│   └── src/
│       └── Worker/
│           └── Worker.csproj
└── shared-lib/
    ├── .git/
    └── Shared/
        └── Shared.csproj
```

## Protected Branches

The script will prompt for a new branch when on:

- `main`
- `master`
- `dev`
- `development`
- `sandbox`

## Example Output

### Folder Selection
```
========================================
   TP.Tools NuGet Upgrade Script
========================================

Root directory: /Users/dev/projects

Step 1: Scanning for .NET projects...

Found 3 subfolder(s) with .NET projects

Step 2: Select folder to process

  0) All folders
  1) api-service (4 .csproj files)
  2) worker-service (2 .csproj files)
  3) shared-lib (1 .csproj files)

Select folder (0-3): 1
Selected: api-service

Step 3: Select mode

  1) Dry run - scan and show packages only
  2) Proceed - scan, upgrade, build, test, commit and push

Select mode (1 or 2): 1
Mode: Dry run
```

### Dry Run Mode (All Folders)
```
========================================
   TP.Tools NuGet Upgrade Script
========================================

Root directory: /Users/dev/projects

Step 1: Scanning for .NET projects...

Found 3 subfolder(s) with .NET projects

Step 2: Select folder to process

  0) All folders
  1) api-service (4 .csproj files)
  2) worker-service (2 .csproj files)
  3) shared-lib (1 .csproj files)

Select folder (0-3): 0
Selected: All folders

Step 3: Select mode

  1) Dry run - scan and show packages only
  2) Proceed - scan, upgrade, build, test, commit and push

Select mode (1 or 2): 1
Mode: Dry run

Step 4: Scanning for TP.Tools.* packages...

Found 4 unique TP.Tools.* package(s)
Found 3 project(s) with TP.Tools.* packages

── Packages Summary ──

  • TP.Tools.Common (versions: 1.0.100, 1.0.98)
  • TP.Tools.Logging (versions: 1.0.100)
  • TP.Tools.Auth (versions: 1.0.95)
  • TP.Tools.Messaging (versions: 1.0.100)

── Projects with TP.Tools.* packages ──

  📁 api-service/src/Api
      • TP.Tools.Common (1.0.100) in Api.csproj
      • TP.Tools.Logging (1.0.100) in Api.csproj

  📁 api-service/src/Api.Core
      • TP.Tools.Auth (1.0.95) in Api.Core.csproj

  📁 worker-service/src/Worker
      • TP.Tools.Common (1.0.98) in Worker.csproj
      • TP.Tools.Messaging (1.0.100) in Worker.csproj

  📁 shared-lib/Shared
      • TP.Tools.Common (1.0.100) in Shared.csproj

========================================
   Dry run completed
========================================

Selected folder(s): api-service worker-service shared-lib
Total unique packages: 4
Total projects to upgrade: 4

Run script again and select mode 2 to proceed with upgrade
```

### Dry Run Mode (Single Folder)
```
========================================
   TP.Tools NuGet Upgrade Script
========================================

Root directory: /Users/dev/projects

Step 1: Scanning for .NET projects...

Found 3 subfolder(s) with .NET projects

Step 2: Select folder to process

  0) All folders
  1) api-service (4 .csproj files)
  2) worker-service (2 .csproj files)
  3) shared-lib (1 .csproj files)

Select folder (0-3): 2
Selected: worker-service

Step 3: Select mode

  1) Dry run - scan and show packages only
  2) Proceed - scan, upgrade, build, test, commit and push

Select mode (1 or 2): 1
Mode: Dry run

Step 4: Scanning for TP.Tools.* packages...

Found 2 unique TP.Tools.* package(s)
Found 1 project(s) with TP.Tools.* packages

── Packages Summary ──

  • TP.Tools.Common (versions: 1.0.98)
  • TP.Tools.Messaging (versions: 1.0.100)

── Projects with TP.Tools.* packages ──

  📁 worker-service/src/Worker
      • TP.Tools.Common (1.0.98) in Worker.csproj
      • TP.Tools.Messaging (1.0.100) in Worker.csproj

========================================
   Dry run completed
========================================

Selected folder(s): worker-service
Total unique packages: 2
Total projects to upgrade: 1

Run script again and select mode 2 to proceed with upgrade
```

### Proceed Mode (Full Output)
```
========================================
   TP.Tools NuGet Upgrade Script
========================================

Root directory: /Users/dev/projects

Step 1: Scanning for .NET projects...

Found 3 subfolder(s) with .NET projects

Step 2: Select folder to process

  0) All folders
  1) api-service (4 .csproj files)
  2) worker-service (2 .csproj files)
  3) shared-lib (1 .csproj files)

Select folder (0-3): 0
Selected: All folders

Step 3: Select mode

  1) Dry run - scan and show packages only
  2) Proceed - scan, upgrade, build, test, commit and push

Select mode (1 or 2): 2
Mode: Proceed with upgrade

Step 4: Scanning for TP.Tools.* packages...

Found 4 unique TP.Tools.* package(s)
Found 4 project(s) with TP.Tools.* packages

── Packages Summary ──

  • TP.Tools.Common (versions: 1.0.100, 1.0.98)
  • TP.Tools.Logging (versions: 1.0.100)
  • TP.Tools.Auth (versions: 1.0.95)
  • TP.Tools.Messaging (versions: 1.0.100)

── Projects with TP.Tools.* packages ──

  📁 api-service/src/Api
      • TP.Tools.Common (1.0.100) in Api.csproj
      • TP.Tools.Logging (1.0.100) in Api.csproj

  📁 api-service/src/Api.Core
      • TP.Tools.Auth (1.0.95) in Api.Core.csproj

  📁 worker-service/src/Worker
      • TP.Tools.Common (1.0.98) in Worker.csproj
      • TP.Tools.Messaging (1.0.100) in Worker.csproj

  📁 shared-lib/Shared
      • TP.Tools.Common (1.0.100) in Shared.csproj

Step 5: Enter target version

Enter upgrade version (format: 1.0.****): 1.0.150
Version accepted: 1.0.150

Step 6: Checking git repositories...

  📂 Git repo: api-service
     Branch: development
     Warning: Protected branch detected
     Enter new branch name for api-service: feature/upgrade-nugets-1.0.150
     Created branch: feature/upgrade-nugets-1.0.150

  📂 Git repo: worker-service
     Branch: feature/worker-updates

  📂 Git repo: shared-lib
     Branch: main
     Warning: Protected branch detected
     Enter new branch name for shared-lib: feature/upgrade-nugets-1.0.150
     Created branch: feature/upgrade-nugets-1.0.150

Step 7: Upgrading packages to version 1.0.150...

── Upgrading: api-service/src/Api ──
  Upgrading TP.Tools.Common in Api.csproj...
    ✓ Success
  Upgrading TP.Tools.Logging in Api.csproj...
    ✓ Success

── Upgrading: api-service/src/Api.Core ──
  Upgrading TP.Tools.Auth in Api.Core.csproj...
    ✓ Success

── Upgrading: worker-service/src/Worker ──
  Upgrading TP.Tools.Common in Worker.csproj...
    ✓ Success
  Upgrading TP.Tools.Messaging in Worker.csproj...
    ✓ Success

── Upgrading: shared-lib/Shared ──
  Upgrading TP.Tools.Common in Shared.csproj...
    ✓ Success

All packages upgraded successfully!

Step 8: Building projects...

── Building: api-service/src/Api ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Api.Core -> /projects/api-service/src/Api.Core/bin/Debug/net8.0/Api.Core.dll
  Api -> /projects/api-service/src/Api/bin/Debug/net8.0/Api.dll
✓ Build succeeded

── Building: worker-service/src/Worker ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Worker -> /projects/worker-service/src/Worker/bin/Debug/net8.0/Worker.dll
✓ Build succeeded

── Building: shared-lib/Shared ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Shared -> /projects/shared-lib/Shared/bin/Debug/net8.0/Shared.dll
✓ Build succeeded

All projects built successfully!

Step 9: Running tests...

── Testing: api-service/src/Api ──
  Determining projects to restore...
  All projects are up-to-date for restore.
Test run for /projects/api-service/tests/Api.Tests/bin/Debug/net8.0/Api.Tests.dll
Passed!  - Failed:     0, Passed:    42, Skipped:     0, Total:    42
✓ Tests passed

── Testing: worker-service/src/Worker ──
  Determining projects to restore...
  No test projects found.
✓ Tests passed

── Testing: shared-lib/Shared ──
  Determining projects to restore...
  No test projects found.
✓ Tests passed

All tests passed!

Step 10: Committing and pushing changes...

── Git repo: api-service ──
[feature/upgrade-nugets-1.0.150 a1b2c3d] Nugets upgraded to version 1.0.150
 2 files changed, 4 insertions(+), 4 deletions(-)
✓ Changes committed
Pushing to origin/feature/upgrade-nugets-1.0.150...
✓ Pushed successfully

── Git repo: worker-service ──
[feature/worker-updates e4f5g6h] Nugets upgraded to version 1.0.150
 1 file changed, 2 insertions(+), 2 deletions(-)
✓ Changes committed
Pushing to origin/feature/worker-updates...
✓ Pushed successfully

── Git repo: shared-lib ──
[feature/upgrade-nugets-1.0.150 i7j8k9l] Nugets upgraded to version 1.0.150
 1 file changed, 1 insertion(+), 1 deletion(-)
✓ Changes committed
Pushing to origin/feature/upgrade-nugets-1.0.150...
✓ Pushed successfully

========================================
   Upgrade completed successfully!
========================================

Selected folder(s): api-service worker-service shared-lib
Target version: 1.0.150
Packages upgraded: 4
Projects upgraded: 4

Upgraded packages:
  • TP.Tools.Common
  • TP.Tools.Logging
  • TP.Tools.Auth
  • TP.Tools.Messaging
```

### Build Failure Example
```
Step 8: Building projects...

── Building: api-service/src/Api ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
/projects/api-service/src/Api/Controllers/UserController.cs(45,13): error CS1061: 'IAuthService' does not contain a definition for 'ValidateTokenAsync'
✗ Build failed

Some projects failed to build. Please fix errors before continuing.
```

### Test Failure Example
```
Step 9: Running tests...

── Testing: api-service/src/Api ──
  Determining projects to restore...
Test run for /projects/api-service/tests/Api.Tests/bin/Debug/net8.0/Api.Tests.dll

Failed!  - Failed:     2, Passed:    40, Skipped:     0, Total:    42
✗ Tests failed

Failed tests:
  ✗ UserServiceTests.CreateUser_WithInvalidEmail_ThrowsException
  ✗ AuthServiceTests.ValidateToken_ExpiredToken_ReturnsFalse

Some tests failed. Please fix failing tests before continuing.
```

## Configuration

Edit the script to customize:
```bash
# Protected branches (line 17)
PROTECTED_BRANCHES=("main" "master" "dev" "development" "sandbox")

# Package prefix (line 20)
NUGET_PREFIX="TP.Tools"

# Version pattern (line 168)
version_pattern='^1\.0\.[0-9]+$'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `No .NET projects found` | Run from correct root directory |
| `No TP.Tools.* packages found` | Check package prefix matches your packages |
| Invalid folder selection | Enter number between 0 and max shown |
| Package upgrade fails | Verify package exists in NuGet source |
| Build fails | Fix code issues, then re-run script |
| Tests fail | Fix failing tests, then re-run script |
| Push fails | Check remote access, push manually if needed |
| `command not found: dotnet` | Install .NET SDK |

## Compatibility

- ✅ macOS (Bash 3.2+)
- ✅ Linux (Bash 4.0+)
- ✅ Git 2.0+
- ✅ .NET 6.0+ SDK

## License

MIT License