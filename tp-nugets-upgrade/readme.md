# TP.Tools NuGet Upgrade Script

A bash script that automates upgrading all `TP.Tools.*` NuGet packages across multiple .NET projects and repositories.

## Features

- 🔍 **Auto-discovery** - Recursively finds all `TP.Tools.*` packages across all `.csproj` files
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

## Modes

| Mode | Description |
|------|-------------|
| **Dry run** | Scans and displays all packages without making changes |
| **Proceed** | Full upgrade: scan → upgrade → build → test → commit → push |

## Workflow

| Step | Action | On Failure |
|------|--------|------------|
| 0 | Select mode (dry run / proceed) | - |
| 1 | Scan directories for `.csproj` files | Exit if none found |
| 2 | Find all `TP.Tools.*` packages | Exit if none found |
| 3 | Prompt for target version (`1.0.****`) | Re-prompt until valid |
| 4 | Check branches, prompt for new if protected | Must provide valid name |
| 5 | Upgrade all packages via `dotnet add package` | Exit on error |
| 6 | Run `dotnet build` for each project | Show errors and exit |
| 7 | Run `dotnet test` for each project | Show failed tests and exit |
| 8 | Commit and push changes | Report push failures |

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

### Dry Run Mode
```
========================================
   TP.Tools NuGet Upgrade Script
========================================

Root directory: /Users/dev/projects

Step 0: Select mode

  1) Dry run - scan and show packages only
  2) Proceed - scan, upgrade, build, test, commit and push

Select mode (1 or 2): 1
Mode: Dry run

Step 1: Scanning for .NET projects...

Found 6 .csproj file(s)

Step 2: Scanning for TP.Tools.* packages...

Found 4 unique TP.Tools.* package(s)
Found 3 project(s) with TP.Tools.* packages

── Packages Summary ──

  • TP.Tools.Common (versions: 1.0.100, 1.0.98)
  • TP.Tools.Logging (versions: 1.0.100)
  • TP.Tools.Auth (versions: 1.0.95)
  • TP.Tools.Messaging (versions: 1.0.100)

── Projects with TP.Tools.* packages ──

  📁 api-service
      • TP.Tools.Common (1.0.100) in Api.csproj
      • TP.Tools.Logging (1.0.100) in Api.csproj
      • TP.Tools.Auth (1.0.95) in Api.Core.csproj

  📁 worker-service
      • TP.Tools.Common (1.0.98) in Worker.csproj
      • TP.Tools.Messaging (1.0.100) in Worker.csproj

  📁 shared-lib
      • TP.Tools.Common (1.0.100) in Shared.csproj

========================================
   Dry run completed
========================================

Total unique packages: 4
Total projects to upgrade: 3

Run script again and select mode 2 to proceed with upgrade
```

### Proceed Mode
```
========================================
   TP.Tools NuGet Upgrade Script
========================================

Root directory: /Users/dev/projects

Step 0: Select mode

  1) Dry run - scan and show packages only
  2) Proceed - scan, upgrade, build, test, commit and push

Select mode (1 or 2): 2
Mode: Proceed with upgrade

Step 1: Scanning for .NET projects...

Found 6 .csproj file(s)

Step 2: Scanning for TP.Tools.* packages...

Found 4 unique TP.Tools.* package(s)
Found 3 project(s) with TP.Tools.* packages

── Packages Summary ──

  • TP.Tools.Common (versions: 1.0.100, 1.0.98)
  • TP.Tools.Logging (versions: 1.0.100)
  • TP.Tools.Auth (versions: 1.0.95)
  • TP.Tools.Messaging (versions: 1.0.100)

── Projects with TP.Tools.* packages ──

  📁 api-service
      • TP.Tools.Common (1.0.100) in Api.csproj
      • TP.Tools.Logging (1.0.100) in Api.csproj
      • TP.Tools.Auth (1.0.95) in Api.Core.csproj

  📁 worker-service
      • TP.Tools.Common (1.0.98) in Worker.csproj
      • TP.Tools.Messaging (1.0.100) in Worker.csproj

  📁 shared-lib
      • TP.Tools.Common (1.0.100) in Shared.csproj

Step 3: Enter target version

Enter upgrade version (format: 1.0.****): 1.0.150
Version accepted: 1.0.150

Step 4: Checking git repositories...

  📂 Git repo: api-service
     Branch: development
     Warning: Protected branch detected
     Enter new branch name for api-service: feature/upgrade-nugets-1.0.150
     Created branch: feature/upgrade-nugets-1.0.150

  📂 Git repo: worker-service
     Branch: feature/worker-updates
     (Not protected, continuing)

  📂 Git repo: shared-lib
     Branch: main
     Warning: Protected branch detected
     Enter new branch name for shared-lib: feature/upgrade-nugets-1.0.150
     Created branch: feature/upgrade-nugets-1.0.150

Step 5: Upgrading packages to version 1.0.150...

── Upgrading: api-service ──
  Upgrading TP.Tools.Common in Api.csproj...
    ✓ Success
  Upgrading TP.Tools.Logging in Api.csproj...
    ✓ Success
  Upgrading TP.Tools.Auth in Api.Core.csproj...
    ✓ Success

── Upgrading: worker-service ──
  Upgrading TP.Tools.Common in Worker.csproj...
    ✓ Success
  Upgrading TP.Tools.Messaging in Worker.csproj...
    ✓ Success

── Upgrading: shared-lib ──
  Upgrading TP.Tools.Common in Shared.csproj...
    ✓ Success

All packages upgraded successfully!

Step 6: Building projects...

── Building: api-service ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Api.Core -> /projects/api-service/src/Api.Core/bin/Debug/net8.0/Api.Core.dll
  Api -> /projects/api-service/src/Api/bin/Debug/net8.0/Api.dll
✓ Build succeeded

── Building: worker-service ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Worker -> /projects/worker-service/src/Worker/bin/Debug/net8.0/Worker.dll
✓ Build succeeded

── Building: shared-lib ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  Shared -> /projects/shared-lib/Shared/bin/Debug/net8.0/Shared.dll
✓ Build succeeded

All projects built successfully!

Step 7: Running tests...

── Testing: api-service ──
  Determining projects to restore...
  All projects are up-to-date for restore.
Test run for /projects/api-service/tests/Api.Tests/bin/Debug/net8.0/Api.Tests.dll
Passed!  - Failed:     0, Passed:    42, Skipped:     0, Total:    42
✓ Tests passed

── Testing: worker-service ──
  Determining projects to restore...
  No test projects found.
✓ Tests passed

── Testing: shared-lib ──
  Determining projects to restore...
  No test projects found.
✓ Tests passed

All tests passed!

Step 8: Committing and pushing changes...

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

Target version: 1.0.150
Packages upgraded: 4
Projects upgraded: 3

Upgraded packages:
  • TP.Tools.Common
  • TP.Tools.Logging
  • TP.Tools.Auth
  • TP.Tools.Messaging
```

### Build Failure Example
```
Step 6: Building projects...

── Building: api-service ──
MSBuild version 17.8.0 for .NET
  Determining projects to restore...
/projects/api-service/src/Api/Controllers/UserController.cs(45,13): error CS1061: 'IAuthService' does not contain a definition for 'ValidateTokenAsync'
✗ Build failed

Some projects failed to build. Please fix errors before continuing.
```

### Test Failure Example
```
Step 7: Running tests...

── Testing: api-service ──
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

# Version pattern (line 97)
version_pattern='^1\.0\.[0-9]+$'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `No .csproj files found` | Run from correct root directory |
| `No TP.Tools.* packages found` | Check package prefix matches your packages |
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
