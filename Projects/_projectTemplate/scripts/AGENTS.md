# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

PowerShell WPF GUI (`project_manager.ps1`) and CLI scripts for managing a 3-layer project workspace:

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

## Core CLI Scripts

```powershell
.\setup_project.ps1 -ProjectName "NewProject"
.\setup_project.ps1 -ProjectName "SupportTask" -Tier mini
.\setup_project.ps1 -ProjectName "GenAI-Tools" -Category domain
.\setup_project.ps1 -ProjectName "SmallDomain" -Tier mini -Category domain

.\check_project.ps1 -ProjectName "MyProject"
.\archive_project.ps1 -ProjectName "OldProject" [-DryRun] [-Force]
.\convert_tier.ps1 -ProjectName "MyProject" -To full [-DryRun]
```

## Project Structure

Full tier:
```
<project>/
  _ai-context/
    context/          -> Obsidian-Vault/Projects/<project>/ai-context/  (junction)
    obsidian_notes/   -> Obsidian-Vault/Projects/<project>/             (junction)
  _ai-workspace/      (local only, full tier only)
  shared/             -> Box/Projects/<project>/                        (junction)
  development/source/
  AGENTS.md
  CLAUDE.md
```

Mini tier omits `_ai-workspace/`. Domain projects live under `_domains/` or `_domains/_mini/`.

## GUI Module Architecture

Entry point `project_manager.ps1` dot-sources all modules from `manager/` in this order:

```
Config.ps1             -> $script:AppState, Initialize-AppConfig
Theme.ps1              -> Get-ThemeColors, Get-ThemeResourcesXaml
ScriptRunner.ps1       -> Invoke-ScriptWithOutput, Get-ProjectParams
ProjectDiscovery.ps1   -> Get-ProjectNameList, Get-ProjectInfoList, Start-BoxProjectsAsyncRefresh
EditorHelpers.ps1      -> Open-FileInEditor, Save-EditorFile, Get-FileEncoding, Read-FileContent, Save-FileContent
XamlBuilder.ps1        -> Build-MainWindowXaml  (must run BEFORE window is created)
TrayManager.ps1        -> Initialize-TrayIcon, Register-GlobalHotkey, Invoke-TrayExit, Test-ForceExit
TabDashboard.ps1       -> Initialize-TabDashboard
TabEditor.ps1          -> Initialize-TabEditor  (dot-sources TabEditorContextMenu.ps1 internally)
TabSetup.ps1           -> Initialize-TabSetup
TabCheck.ps1           -> Initialize-TabCheck
TabArchive.ps1         -> Initialize-TabArchive
TabContextSetup.ps1    -> Initialize-TabContextSetup
TabConvert.ps1         -> Initialize-TabConvert
TabAsanaSync.ps1       -> Initialize-TabAsanaSync
TabSettings.ps1        -> Initialize-TabSettings
TabTimeline.ps1        -> Initialize-TabTimeline
CommandPalette.ps1     -> Initialize-CommandPalette
FeatureMorningBriefing.ps1 -> Invoke-MorningBriefing
```

`TabEditorContextMenu.ps1` is NOT in the main dot-source list. It is loaded by `TabEditor.ps1` via `. (Join-Path $PSScriptRoot "TabEditorContextMenu.ps1")`.

Tab index mapping — source of truth is the comment at the top of `XamlBuilder.ps1`:
- 0=Dashboard, 1=Editor, 2=Timeline, 3=Setup, 4=AI Context, 5=Check, 6=Archive, 7=Convert, 8=Asana Sync, 9=Settings

## AppState

`$script:AppState` (defined in `Config.ps1`) is the global state shared across all modules:

```powershell
$script:AppState = @{
    WorkspaceRoot   = ""
    ScriptDir       = ""
    PathsConfig     = $null
    Theme           = "Default"
    Projects        = @()
    HiddenProjects  = @()
    SelectedProject = $null
    EditorControl   = $null    # AvalonEdit TextEditor reference (set by TabEditor)
    EditorState     = @{
        CurrentFile         = ""
        OriginalContent     = ""
        IsDirty             = $false
        Encoding            = "UTF8"   # UTF8 / UTF8BOM / SJIS / UTF16LE / UTF16BE
        SuppressChangeEvent = $false
    }
}
```

Settings persist to `_config/settings.json`; hidden projects to `_config/hidden_projects.json`.
Hidden project key format: `"Name|Tier|Category"`.

## Project Discovery

`ProjectDiscovery.ps1` exports:
- `Get-ProjectNameList` - string list for dropdowns: `ProjectA`, `Name [Mini]`, `Name [Domain]`, `Name [Domain][Mini]`, `Name [BOX]`
- `Get-ProjectInfoList [-Force] [-SkipTokens]` - full `ProjectInfo` hashtables; cached 300 seconds (5 minutes)

`ProjectInfo` fields: `Name`, `Tier`, `Category`, `Path`, `AiContextPath`, `AiContextContentPath`,
`JunctionShared/Obsidian/Context` (OK/Missing/Broken),
`FocusFile`, `SummaryFile`, `FileMapFile`, `AgentsFile`, `ClaudeFile`,
`FocusLines`, `SummaryLines`, `FocusTokens`, `SummaryTokens`,
`FocusAge`, `SummaryAge` (days), `DecisionLogCount`, `FocusHistoryDates`, `DecisionLogDates`.

`Get-ProjectParams` (in `ScriptRunner.ps1`) strips `[BOX]`, `[Domain]`, `[Mini]`, `[Domain][Mini]` suffixes
from combo box display text and returns `@{ Name; IsMini; IsDomain }`.

## Key Behaviors

- Close button hides to tray; Shift+Click forces exit
- Escape: close command palette first, then hide window
- Ctrl+K: toggle command palette
- Ctrl+1..0: switch tabs (index 0..9)
- Single-instance enforced via named Mutex `Global\ProjectManager_SingleInstance`
- BOX-only projects are fetched asynchronously via Runspace + DispatcherTimer polling (after window load)

---

## ENCODING RULES — READ BEFORE EDITING ANY .ps1 FILE

PowerShell 5.1 (Windows PowerShell) reads `.ps1` files as Shift_JIS (cp932) by default.
The Write/Edit tools produce UTF-8. Embedding Japanese characters directly in `.ps1` causes mojibake at runtime.

Rules:
- Do NOT embed Japanese strings directly in `.ps1` files.
- In XAML strings: use XML Unicode escapes (`&#x30D7;&#x30ED;` etc.) for all Japanese text.
- For UI labels that must be set from PowerShell code: use ASCII or pass via variable from a file read as UTF-8.
- `Config.ps1` auto-detects BOM / UTF-8 / SJIS when reading `paths.json` (do not change this logic).
- `EditorHelpers.ps1` handles BOM detection -> UTF-8 strict -> SJIS fallback for file editing.

---

## BUG-PRONE PATTERNS — FOLLOW THESE EXACTLY

### 1. Editor text update (SuppressChangeEvent + AppState order)

When loading a file into the AvalonEdit editor, ALWAYS:
1. Update `$script:AppState.EditorState` FIRST (so the TextChanged handler sees correct state).
2. Set `SuppressChangeEvent = $true` BEFORE assigning `$editor.Text`.
3. Set `SuppressChangeEvent = $false` AFTER the assignment.

```powershell
# CORRECT
$script:AppState.EditorState.CurrentFile    = $FilePath
$script:AppState.EditorState.OriginalContent = $content
$script:AppState.EditorState.IsDirty        = $false
$script:AppState.EditorState.Encoding       = $encoding
$script:AppState.EditorState.SuppressChangeEvent = $true
$editor.Text = $content
$script:AppState.EditorState.SuppressChangeEvent = $false
```

The TextChanged handler must check `SuppressChangeEvent` and return early if it is `$true`.

### 2. FindName null checks

`$window.FindName("controlName")` returns `$null` if the name does not exist.
ALWAYS null-check before use:

```powershell
$btn = $window.FindName("btnFoo")
if ($null -ne $btn) { $btn.IsEnabled = $false }
```

Never assume a control name exists. Typos in XAML x:Name or a renamed control will cause silent failures
or NullReferenceException crashes.

### 3. XAML x:Name uniqueness

All `x:Name` attributes across ALL tab XAML fragments (generated in `XamlBuilder.ps1`) must be globally
unique within the window. Duplicate names cause `XamlReader::Load` to throw, crashing startup.

### 4. ConvertTo-Json single-item array unrolling

`ConvertTo-Json` unrolls a single-item array to a plain object. Always wrap with `-InputObject @(...)`:

```powershell
# CORRECT — preserves array even for 0 or 1 items
ConvertTo-Json -InputObject @($script:AppState.HiddenProjects) | Set-Content $path -Encoding UTF8
```

### 5. ScriptRunner stream merging

`Invoke-ScriptWithOutput` uses `*>&1` to merge all streams (including `Write-Host`) into stdout.
This is intentional to avoid Runspace/BeginErrorReadLine conflicts.
Do NOT split it back to separate stdout/stderr handling.

### 6. Background Runspace isolation

Background Runspaces (e.g., in `Start-BoxProjectsAsyncRefresh`) do NOT inherit `$script:AppState`.
When creating a Runspace, explicitly inject all required state via `SetVariable`:

```powershell
$rs.SessionStateProxy.SetVariable('_WorkspaceRoot', $workspaceRoot)
$rs.SessionStateProxy.SetVariable('_PathsConfig',   $pathsConfig)
```

Inside the Runspace script block, reconstruct the minimal `$script:AppState` needed before calling
any function from `ProjectDiscovery.ps1` or other modules.

### 7. Returning background results to the UI thread

Use a DispatcherTimer polling pattern. Do NOT use `Add_Completed` callbacks from background threads —
they run on the thread pool, not the WPF dispatcher, and will crash when touching UI controls.

```powershell
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [timespan]::FromMilliseconds(200)
$timer.Tag = @{ PS = $ps; RS = $rs; Handle = $asyncHandle; Window = $Window }
$timer.Add_Tick({
    param($sender, $e)
    $d = $sender.Tag
    if (-not $d.Handle.IsCompleted) { return }
    $sender.Stop()
    try {
        $results = $d.PS.EndInvoke($d.Handle)
        # safe to touch UI here — we are on the Dispatcher thread
    } catch { }
    finally { $d.PS.Dispose(); $d.RS.Close(); $d.RS.Dispose() }
}.GetNewClosure())
$timer.Start()
```

### 8. SelectionChanged initial fire

To ensure a `SelectionChanged` handler fires on startup:
1. Register the handler first.
2. Then set `SelectedIndex = 0` (change from -1 to 0 triggers the event).

If you set `SelectedIndex = 0` before registering the handler, no event fires.

### 9. Cache refresh after mutations

After any tab operation that modifies the project list (setup, archive, convert), you must refresh:
- `$script:AppState.Projects` via `Get-ProjectInfoList -Force`
- All dropdown ComboBoxes via `Get-ProjectNameList` (rebuild Items)

Stale cached data will make the Dashboard and other tabs show outdated information.

### 10. Event handler exception isolation

Uncaught exceptions inside WPF event handlers (Add_Click, Add_SelectionChanged, etc.) propagate to the
WPF Dispatcher and can crash the application. Wrap handler bodies in `try { ... } catch { }`:

```powershell
$btn.Add_Click({
    try {
        # ... your logic ...
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error") | Out-Null
    }
})
```

---

## Theme System

`Theme.ps1` supports two themes: `Default` (Catppuccin Mocha) and `GitHub` (GitHub Dark).
Color tokens like `{{Base}}`, `{{Text}}`, `{{Mauve}}` are replaced in the XAML template string
by `Build-MainWindowXaml`. Theme preference persists in `_config/settings.json`.

When adding new XAML that uses theme colors, use the token syntax `{{TokenName}}` — do NOT hardcode
hex values. Available tokens are defined in `Get-ThemeColors` in `Theme.ps1`.

---

## ScriptRunner Pattern

`Invoke-ScriptWithOutput` launches subscripts synchronously:

```powershell
$cmd = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '$ScriptPath' $ArgumentString *>&1"
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
$psi.RedirectStandardOutput = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$process = [System.Diagnostics.Process]::Start($psi)
$output = $process.StandardOutput.ReadToEnd()
$process.WaitForExit()
```

The `ReadToEnd()` before `WaitForExit()` is intentional to drain the pipe and prevent deadlock.
