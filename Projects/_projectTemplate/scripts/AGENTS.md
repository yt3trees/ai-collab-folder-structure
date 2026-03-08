# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This directory contains PowerShell scripts for managing the 3-layer project workspace:

- Layer 1 (Local): `Documents/Projects/<project>/`
- Layer 2 (Knowledge): `Box/Obsidian-Vault/Projects/<project>/`
- Layer 3 (Artifact): `Box/Projects/<project>/`

## Prerequisites

All scripts require `_config/paths.json` at the workspace root (`Documents/Projects/_config/paths.json`):

```json
{
  "localProjectsRoot": "%USERPROFILE%\\Documents\\Projects",
  "boxProjectsRoot": "%USERPROFILE%\\Box\\Projects",
  "obsidianVaultRoot": "%USERPROFILE%\\Box\\Obsidian-Vault"
}
```

## Core Scripts

```powershell
# Create a new project (idempotent - safe to re-run)
.\setup_project.ps1 -ProjectName "NewProject"
.\setup_project.ps1 -ProjectName "SupportTask" -Tier mini
.\setup_project.ps1 -ProjectName "GenAI-Tools" -Category domain
.\setup_project.ps1 -ProjectName "SmallDomain" -Tier mini -Category domain

# Verify junction integrity and AI context file freshness
.\check_project.ps1 -ProjectName "MyProject"
.\check_project.ps1 -ProjectName "MyProject" -Mini -Category domain

# Archive a completed project (moves all 3 layers to _archive/)
.\archive_project.ps1 -ProjectName "OldProject" [-DryRun] [-Force]
.\archive_project.ps1 -ProjectName "OldProject" -Mini

# Convert between tiers (mini <-> full)
.\convert_tier.ps1 -ProjectName "MyProject" -To full [-DryRun]
.\convert_tier.ps1 -ProjectName "MyProject" -To mini [-DryRun]

# Launch the WPF GUI (single-instance, tray-resident)
powershell -ExecutionPolicy Bypass -File project_manager.ps1
```

## Project Structure Created by setup_project.ps1

Full tier:
```
<project>/
  _ai-context/
    context/          -> Obsidian-Vault/Projects/<project>/ai-context/  (junction)
    obsidian_notes/   -> Obsidian-Vault/Projects/<project>/             (junction)
  _ai-workspace/      (local only, full tier only)
  shared/             -> Box/Projects/<project>/                        (junction)
  development/source/
  AGENTS.md           (copy from Box)
  CLAUDE.md           (@AGENTS.md reference)
```

Mini tier omits `_ai-workspace/`. Domain projects live under `_domains/` or `_domains/_mini/`.

## GUI Architecture (project_manager.ps1)

Entry point dot-sources all modules from `manager/`, then builds a WPF window via XAML.

Module load order matters:
1. `Config.ps1` - `$script:AppState` hashtable, `Initialize-AppConfig`, settings/hidden-projects persistence
2. `Theme.ps1`, `ScriptRunner.ps1`, `ProjectDiscovery.ps1`, `EditorHelpers.ps1`
3. `XamlBuilder.ps1` - generates the full XAML string; `Build-MainWindowXaml -ThemeName`
4. `TrayManager.ps1` - system tray icon and global hotkey registration
5. Tab modules (each exports `Initialize-Tab*`): `TabDashboard`, `TabEditor`, `TabSetup`, `TabCheck`, `TabArchive`, `TabContextSetup`, `TabConvert`, `TabAsanaSync`, `TabSettings`, `TabTimeline`
6. `CommandPalette.ps1`

Tab index mapping (Ctrl+N to switch):
- 0=Dashboard, 1=Editor, 2=Setup, 3=Check, 4=Archive, 5=Context, 6=Convert, 7=AsanaSync, 8=Settings, 9=Timeline

Key behaviors:
- Close button hides to tray; Shift+Click forces exit
- Escape closes command palette or hides window
- Ctrl+K toggles command palette
- Single-instance enforced via named Mutex

## AppState

`$script:AppState` (defined in `Config.ps1`) is the global state shared across all modules:

```powershell
$script:AppState = @{
    WorkspaceRoot   = ""      # Documents/Projects/
    PathsConfig     = $null   # parsed paths.json
    Theme           = "Default"
    Projects        = @()     # ProjectInfo hashtables (from ProjectDiscovery)
    HiddenProjects  = @()     # keys: "Name|Tier|Category"
    SelectedProject = $null
    EditorState     = @{ CurrentFile; OriginalContent; IsDirty; Encoding; SuppressChangeEvent }
}
```

## Project Discovery

`ProjectDiscovery.ps1` scans the workspace root for project directories. Naming conventions used in dropdowns:
- Full-tier: plain name (e.g., `ProjectA`)
- Mini-tier: `Name [Mini]`
- Domain: `Name [Domain]`
- Domain mini: `Name [Domain][Mini]`

Results are cached for 30 seconds (`$script:ProjectInfoCacheTTL`).

## Encoding Notes

- All `.ps1` files: UTF-8 (without BOM) when created by Write/Edit tools
- `Config.ps1` auto-detects BOM / UTF-8 / SJIS when reading `paths.json`
- `EditorHelpers.ps1` handles BOM detection -> UTF-8 strict -> SJIS fallback for file editing
- Do not embed Japanese strings directly in `.ps1` files; use XML Unicode escapes (`&#xXXXX;`) in XAML or pass via parameters

## ScriptRunner.ps1 Pattern

Background scripts are launched via `Process` with `*>&1` to merge all streams into stdout, avoiding `BeginErrorReadLine` / runspace conflicts. All `AppendText` calls inside `add_OutputDataReceived` must be wrapped in try/catch to prevent WPF dispatcher crashes.
