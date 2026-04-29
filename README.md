# nsParser NSIS Plugin

Native C plugin for NSIS to extract values from large files, bypassing the NSIS_MAX_STRLEN limit (1 KB).

---

## Problem Solved

NSIS's built-in string functions are limited to `NSIS_MAX_STRLEN` (typically 1024 bytes). When reading configuration files, JSON, or INI files larger than this limit, the string is silently truncated.

`nsParser` solves this by reading only the specific value requested, without loading the entire file into a string.

---

## Build

### Prerequisites

- **Visual Studio 2022** (with "Desktop development with C++" workload)
- **Python 3.x**

### Build script

```powershell
python build_plugin.py
```

### Build options

```powershell
python build_plugin.py --configs x86-unicode      # Single architecture (x86-ansi|x86-unicode|x64-unicode|all)
python build_plugin.py --vs-version 2026          # Specific toolset (auto|2022|2026)
python build_plugin.py --clean                    # Clean dist/ before build
python build_plugin.py --rebuild                  # Force full rebuild
python build_plugin.py --verbosity detailed       # Extended MSBuild output
python build_plugin.py --install-dir "C:\NSIS\Plugins"  # Copy to additional NSIS directory
python build_plugin.py --list                     # List available configurations
```

---

## Usage in NSIS

```nsis
!addplugindir "plugins\x86-unicode"

Section
  nsParser::Extract "C:\config.ini" "key" $0
  DetailPrint "Value: $0"
SectionEnd
```

---

## API

### `nsParser::Extract`

```nsis
nsParser::Extract "FilePath" "Key" $OutputVar
```

**Parameters:**

| Parameter | Description |
|-----------|-------------|
| `FilePath` | Full path to the file to parse |
| `Key`      | Key to search for (e.g. `version`, `path`) |
| `$OutputVar` | Variable to receive the extracted value |

**Search logic:**

The plugin searches for the pattern `Key=Value` or `Key = Value` in the file. If found, returns the value trimmed of leading/trailing whitespace. If not found, returns an empty string.

**Buffer:**

The value is extracted with a buffer of 32768 bytes, well beyond the NSIS_MAX_STRLEN limit. This allows reading long paths and embedded JSON strings.

---

## Advantages

- No dependency on the NSIS string size limit
- Reads only the requested value (efficient on large files)
- Handles `key=value` and `key = value` formats
- Thread-safe (no global state)
- Small binary size

---

## Technical Implementation

The plugin is written in C and uses a direct file reader via `ReadFile` (Win32). The algorithm:

1. Opens the file with `CreateFile` (read-only, shared)
2. Reads the file in 8192-byte blocks
3. Scans each block for the pattern `Key=` or `Key =`
4. Extracts the value up to the first newline (`\n` or `\r\n`)
5. Trims leading/trailing whitespace
6. Returns the result via the NSIS stack

### Visual Studio configurations

| Configuration | Architecture | Output |
|---------------|--------------|--------|
| Release-x86-ansi | x86 ANSI | `plugins/x86-ansi/nsParser.dll` |
| Release-x86-unicode | x86 Unicode | `plugins/x86-unicode/nsParser.dll` |
| Release-amd64-unicode | x64 Unicode | `plugins/amd64-unicode/nsParser.dll` |

---

## File Structure

```
nsParser/
 build_plugin.py          # Unified build script
 src/
    nsParser.c           # Plugin source code
    nsParser.vcxproj     # VS2022 project (x86-ansi, x86-unicode, amd64-unicode)
    nsParser.sln         # VS2022 solution
 dist/
     x86-ansi/
     x86-unicode/
     amd64-unicode/
```

---

*See [README_IT.md](README_IT.md) for the Italian version.*
