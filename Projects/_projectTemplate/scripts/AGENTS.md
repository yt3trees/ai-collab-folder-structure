# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

PowerShell scripts for managing the 3-layer project workspace:

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
# Create a new project (idempotent)
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

`-ExternalSharedPaths` adds extra Box folder junctions under `external_shared/` and persists paths to `shared/.external_shared_paths`.

## GUI Architecture (project_manager.ps1)

Entry point dot-sources all modules from `manager/`, then builds a WPF window via XAML.

Module load order:
1. `Config.ps1` - `$script:AppState` hashtable, `Initialize-AppConfig`, settings/hidden-projects persistence
2. `Theme.ps1`, `ScriptRunner.ps1`, `ProjectDiscovery.ps1`, `EditorHelpers.ps1`
3. `XamlBuilder.ps1` - generates the full XAML string; `Build-MainWindowXaml -ThemeName`
4. `TrayManager.ps1` - system tray icon and global hotkey registration
5. Tab modules (each exports `Initialize-Tab*`): `TabDashboard`, `TabEditor`, `TabSetup`, `TabCheck`, `TabArchive`, `TabContextSetup`, `TabConvert`, `TabAsanaSync`, `TabSettings`, `TabTimeline`
6. `CommandPalette.ps1`, `FeatureMorningBriefing.ps1`

Tab index mapping (Ctrl+1..0 to switch) - source of truth is `XamlBuilder.ps1`:
- 0=Dashboard, 1=Editor, 2=Timeline, 3=Setup, 4=AI Context, 5=Check, 6=Archive, 7=Convert, 8=Asana Sync, 9=Settings

`TabEditorContextMenu.ps1` provides the right-click context menu for the Editor tab.

Key behaviors:
- Close button hides to tray; Shift+Click forces exit
- Escape closes command palette or hides window
- Ctrl+K toggles command palette
- Single-instance enforced via named Mutex

## AppState

`$script:AppState` (defined in `Config.ps1`) is the global state shared across all modules:

```powershell
$script:AppState = @{
    WorkspaceRoot   = ""       # Documents/Projects/
    ScriptDir       = ""       # _projectTemplate/scripts/
    PathsConfig     = $null    # parsed paths.json (env vars expanded)
    Theme           = "Default"
    Projects        = @()      # ProjectInfo hashtables (from ProjectDiscovery)
    HiddenProjects  = @()      # keys: "Name|Tier|Category"
    SelectedProject = $null
    EditorControl   = $null    # AvalonEdit TextEditor control reference
    EditorState     = @{ CurrentFile; OriginalContent; IsDirty; Encoding; SuppressChangeEvent }
}
```

Settings persist to `_config/settings.json`; hidden projects to `_config/hidden_projects.json`.

## Project Discovery

`ProjectDiscovery.ps1` exports two functions:
- `Get-ProjectNameList` - simple strings for dropdowns (e.g., `ProjectA`, `Name [Mini]`, `Name [Domain]`, `Name [Domain][Mini]`, `Name [BOX]`)
- `Get-ProjectInfoList [-Force]` - full `ProjectInfo` hashtables for Dashboard cards; cached 30 seconds

`ProjectInfo` includes junction status (`JunctionShared`, `JunctionObsidian`, `JunctionContext`), AI file paths, file metrics (Lines, Tokens), and decision log/focus history data. Tokens are computed in bulk via `get_tokens.py` if Python is available (`pip install tiktoken`).

## FeatureMorningBriefing.ps1

`Invoke-MorningBriefing -Window $window` generates a 72-hour cross-project summary. Output is saved as `yyyy-MM-dd_Briefing.md` under `_ai-workspace/briefings/` (falls back to `_briefings/`).

## Themes

`Theme.ps1` supports two themes: `Default` (Catppuccin Mocha) and `GitHub` (GitHub Dark). Theme preference persists in `_config/settings.json`. Color tokens (e.g., `{{Base}}`, `{{Text}}`) are replaced in XAML by `Build-MainWindowXaml`.

## Encoding Notes

- All `.ps1` files: UTF-8 without BOM when created by Write/Edit tools
- `Config.ps1` auto-detects BOM / UTF-8 / SJIS when reading `paths.json`
- `EditorHelpers.ps1` handles BOM detection -> UTF-8 strict -> SJIS fallback for file editing
- Do not embed Japanese strings directly in `.ps1` files; use XML Unicode escapes (`&#xXXXX;`) in XAML or pass via parameters

## ScriptRunner.ps1 Pattern

`Invoke-ScriptWithOutput` launches subscripts synchronously via `System.Diagnostics.Process` with `*>&1` to merge all streams (including Write-Host) into stdout. This avoids `BeginErrorReadLine` / runspace conflicts. Output is captured via `ReadToEnd()` after `WaitForExit()` and appended to the output TextBox.
