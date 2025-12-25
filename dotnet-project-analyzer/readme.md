# .NET Code Analyzer

A fast bash script that analyzes .NET/C# codebases to count meaningful lines of code, filtering out boilerplate and non-logic lines. Results are saved as JSON files in each analyzed repository.

## Overview

This tool helps developers understand the actual complexity of their .NET projects by distinguishing between meaningful code and boilerplate. It scans each subfolder containing .NET repositories and saves detailed metrics as a JSON file.

## Features

- **Automatic subfolder scanning** - Analyzes all repositories in subfolders
- **JSON output** - Saves `dotnet-analysis.json` in each analyzed repository
- **Per-project breakdown** - Metrics for each `.csproj` file
- **Smart line filtering** - Identifies and counts only meaningful code
- **NuGet dependency counting** - Tracks package references
- **Grand totals** - Summary across all analyzed repositories
- **Optimized performance** - Uses AWK for fast file processing
- **Cross-platform compatible** - Works with bash 3.x+ (macOS, Linux)

## What Counts as "Meaningful Code"

The analyzer excludes the following from the meaningful code count:

| Excluded | Examples |
|----------|----------|
| Empty lines | Blank lines |
| Braces only | `{`, `}`, `};` |
| Using statements | `using System;` |
| Namespace declarations | `namespace MyApp` |
| Single-line comments | `// comment` |
| XML documentation | `/// <summary>` |
| Multi-line comments | `/* ... */` |
| LINQ method chains | `.Where(...)`, `.Select(...)` on new lines |
| Wrapped strings | String continuations with `+` |
| Attributes | `[HttpGet]`, `[Authorize]` |
| Preprocessor directives | `#region`, `#if`, `#pragma`, etc. |
| Auto-property accessors | `get;`, `set;`, `init;` |

## Installation

1. Download the script:
```bash
curl -O https://path-to-script/analyze-dotnet.sh
```

2. Make it executable:
```bash
chmod +x analyze-dotnet.sh
```

3. Place it in your parent directory containing .NET repositories.

## Usage

```bash
./analyze-dotnet.sh
```

### Step 1: Folder Selection

Select the parent folder containing your repositories:

```
╔════════════════════════════════════════════════════════════╗
║              .NET Code Analyzer - Folder Selection         ║
╚════════════════════════════════════════════════════════════╝

Current directory: /home/user/projects
Each subfolder with .NET projects will be analyzed.
Results will be saved as dotnet-analysis.json in each subfolder.

Available folders:

  [1] . (Current directory)
  [2] .. (Parent directory)
  [3] MyWebApi
  [4] SharedLibrary

  [c] Enter custom path
  [q] Quit

Select folder [1-4, c, or q]:
```

### Step 2: Automatic Analysis

The script automatically:
1. Scans all immediate subfolders
2. Analyzes each subfolder containing `.csproj` files
3. Saves `dotnet-analysis.json` in each analyzed subfolder
4. Displays progress and summary for each repository
5. Shows grand totals at the end

### Sample Console Output

```
════════════════════════════════════════════════════════════
Analyzing: MyWebApi
════════════════════════════════════════════════════════════
  Projects: 4
  C# files: 125
  Processing: 125 / 125 files
  Non-empty lines:  8400
  Meaningful lines: 5300
  Code ratio:       63.10%
  NuGet packages:   40
  Saved: /home/user/projects/MyWebApi/dotnet-analysis.json
```

### JSON Output Format

Each `dotnet-analysis.json` file contains:

```json
{
  "repository": "MyWebApi",
  "analyzedAt": "2025-01-15T10:30:00Z",
  "summary": {
    "totalProjects": 4,
    "totalCsFiles": 125,
    "totalNugetDependencies": 40,
    "totalNonEmptyLines": 8400,
    "totalMeaningfulLines": 5300,
    "meaningfulCodeRatio": 63.10
  },
  "projects": [
    {
      "name": "MyWebApi.Core",
      "csFiles": 45,
      "nugetDependencies": 12,
      "nonEmptyLines": 3500,
      "meaningfulLines": 2100,
      "ratio": 60.00
    },
    {
      "name": "MyWebApi.Services",
      "csFiles": 32,
      "nugetDependencies": 8,
      "nonEmptyLines": 2200,
      "meaningfulLines": 1450,
      "ratio": 65.91
    }
  ]
}
```

### Grand Totals

At the end of the analysis, a summary is displayed:

```
╔════════════════════════════════════════════════════════════╗
║                       GRAND TOTALS                         ║
╠════════════════════════════════════════════════════════════╣
║ Analyzed subfolders:                                     2 ║
║ Total projects (*.csproj):                               6 ║
║ Total C# files (*.cs):                                 165 ║
║ Total NuGet dependencies:                               52 ║
╠════════════════════════════════════════════════════════════╣
║ Total non-empty lines:                               10200 ║
║ Total meaningful lines:                               6570 ║
║ Overall code ratio:                                  64.41% ║
║ Average ratio per repository:                        64.50% ║
╚════════════════════════════════════════════════════════════╝
```

## Requirements

- **Bash 3.x or higher** (compatible with macOS default bash)
- **Standard Unix utilities**: `find`, `grep`, `awk`, `sed`, `wc`, `sort`, `md5sum` (or `md5` on macOS)

## Directory Structure

The script expects to be placed in a parent directory containing one or more .NET repositories:

```
projects/
├── analyze-dotnet.sh
├── Repository1/
│   ├── dotnet-analysis.json    ← Created by script
│   ├── src/
│   │   ├── Project1/
│   │   │   ├── Project1.csproj
│   │   │   └── *.cs files
│   │   └── Project2/
│   │       ├── Project2.csproj
│   │       └── *.cs files
│   └── tests/
└── Repository2/
    ├── dotnet-analysis.json    ← Created by script
    └── ...
```

## Performance

The script uses AWK for file processing instead of bash line-by-line reading, providing **5-10x faster** analysis compared to pure bash implementations.

## Notes

- Only subfolders containing `.csproj` files are analyzed
- The JSON file is overwritten on each run
- Only `*.cs` files are analyzed; other file types are ignored
- The script uses temporary files for processing (automatically cleaned up)

## License

MIT License - Feel free to use and modify as needed.