# Config.ps1 - AppState initialization and path resolution
# Encoding: UTF-8 (ASCII-safe content)

$script:AppState = @{
    WorkspaceRoot    = ""
    PathsConfig      = $null
    Projects         = @()
    SelectedProject  = $null
    EditorState      = @{
        CurrentFile     = ""
        OriginalContent = ""
        IsDirty         = $false
        Encoding        = "UTF8"
    }
}

function Initialize-AppConfig {
    param([string]$ScriptDir)

    $script:AppState.WorkspaceRoot = Split-Path (Split-Path $ScriptDir)

    # Try to load paths from _config/paths.json
    $configPath = Join-Path $script:AppState.WorkspaceRoot "_config\paths.json"
    if (Test-Path $configPath) {
        try {
            $json = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
            $script:AppState.PathsConfig = $json | ConvertFrom-Json
        } catch {
            # Fall through to defaults
        }
    }

    # Default paths if config not found
    if ($null -eq $script:AppState.PathsConfig) {
        $script:AppState.PathsConfig = [PSCustomObject]@{
            BoxProjects   = Join-Path $env:USERPROFILE "Box\Projects"
            ObsidianVault = Join-Path $env:USERPROFILE "Box\Obsidian-Vault"
        }
    }
}

function Get-WorkspaceRoot {
    return $script:AppState.WorkspaceRoot
}

function Update-StatusBar {
    param(
        [System.Windows.Window]$Window,
        [string]$Project = $null,
        [string]$File = $null,
        [string]$Encoding = $null,
        [bool]$Dirty = $false
    )

    $statusProject = $Window.FindName("statusProject")
    $statusFile    = $Window.FindName("statusFile")
    $statusEncoding = $Window.FindName("statusEncoding")
    $statusDirty   = $Window.FindName("statusDirty")

    if ($null -ne $Project -and $null -ne $statusProject) {
        $statusProject.Text = $Project
    }
    if ($null -ne $File -and $null -ne $statusFile) {
        $statusFile.Text = $File
    }
    if ($null -ne $Encoding -and $null -ne $statusEncoding) {
        $statusEncoding.Text = $Encoding
    }
    if ($null -ne $statusDirty) {
        $statusDirty.Text = if ($Dirty) { "Modified" } else { "" }
        $col = if ($Dirty) { "#f9e2af" } else { "#6c7086" }
        $statusDirty.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString($col)
        )
    }
}
