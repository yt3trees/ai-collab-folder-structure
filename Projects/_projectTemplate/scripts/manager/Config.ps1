# Config.ps1 - AppState initialization and path resolution
# Encoding: UTF-8 (ASCII-safe content)

$script:AppState = @{
    WorkspaceRoot   = ""
    ScriptDir       = ""
    PathsConfig     = $null
    Projects        = @()
    HiddenProjects  = @()
    SelectedProject = $null
    EditorControl   = $null
    EditorState     = @{
        CurrentFile         = ""
        OriginalContent     = ""
        IsDirty             = $false
        Encoding            = "UTF8"
        SuppressChangeEvent = $false
    }
}

function Initialize-AppConfig {
    param([string]$ScriptDir)

    $script:AppState.ScriptDir    = $ScriptDir
    $script:AppState.WorkspaceRoot = Split-Path (Split-Path $ScriptDir)

    # Try to load paths from _config/paths.json
    $configPath = Join-Path $script:AppState.WorkspaceRoot "_config\paths.json"
    if (Test-Path $configPath) {
        try {
            # Detect encoding: UTF-8 BOM -> UTF-8 -> cp932 (SJIS)
            $rawBytes = [System.IO.File]::ReadAllBytes($configPath)
            $detectedEncoding = [System.Text.Encoding]::UTF8
            if ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
                $detectedEncoding = New-Object System.Text.UTF8Encoding($true)
            }
            else {
                try {
                    $testStr = [System.Text.Encoding]::UTF8.GetString($rawBytes)
                    $null = $testStr | ConvertFrom-Json
                    $detectedEncoding = New-Object System.Text.UTF8Encoding($false)
                }
                catch {
                    $detectedEncoding = [System.Text.Encoding]::GetEncoding(932)
                }
            }
            $json = $detectedEncoding.GetString($rawBytes)
            if ($json.Length -gt 0 -and $json[0] -eq [char]0xFEFF) {
                $json = $json.Substring(1)
            }
            $script:AppState.PathsConfig = $json | ConvertFrom-Json
            foreach ($prop in $script:AppState.PathsConfig.PSObject.Properties) {
                if ($prop.Value -is [string]) {
                    $prop.Value = [System.Environment]::ExpandEnvironmentVariables($prop.Value)
                }
            }
        }
        catch {
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

    Load-HiddenProjects
}

# ---- Hidden Projects (Dashboard) ----

function Get-HiddenProjectsPath {
    $configDir = Join-Path $script:AppState.WorkspaceRoot "_config"
    return Join-Path $configDir "hidden_projects.json"
}

function Load-HiddenProjects {
    $path = Get-HiddenProjectsPath
    if (Test-Path $path) {
        try {
            $json   = Get-Content $path -Raw -Encoding UTF8
            $loaded = $json | ConvertFrom-Json
            $script:AppState.HiddenProjects = if ($null -eq $loaded) { @() } else { @($loaded) }
        }
        catch {
            $script:AppState.HiddenProjects = @()
        }
    }
}

function Save-HiddenProjects {
    $path = Get-HiddenProjectsPath
    $dir  = Split-Path $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ($script:AppState.HiddenProjects.Count -eq 0) {
        Set-Content $path -Value "[]" -Encoding UTF8
    }
    else {
        # Use -InputObject to prevent unrolling of single-item arrays
        ConvertTo-Json -InputObject @($script:AppState.HiddenProjects) | Set-Content $path -Encoding UTF8
    }
}

function Get-ProjectHiddenKey {
    param([hashtable]$Info)
    return "$($Info.Name)|$($Info.Tier)|$($Info.Category)"
}

function Test-ProjectHidden {
    param([hashtable]$Info)
    return ($script:AppState.HiddenProjects -contains (Get-ProjectHiddenKey -Info $Info))
}

function Set-ProjectHidden {
    param([hashtable]$Info, [bool]$Hidden)
    $key = Get-ProjectHiddenKey -Info $Info
    if ($Hidden) {
        if (-not ($script:AppState.HiddenProjects -contains $key)) {
            $script:AppState.HiddenProjects = @($script:AppState.HiddenProjects) + $key
        }
    }
    else {
        $script:AppState.HiddenProjects = @($script:AppState.HiddenProjects | Where-Object { $_ -ne $key })
    }
    Save-HiddenProjects
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
    $statusFile = $Window.FindName("statusFile")
    $statusEncoding = $Window.FindName("statusEncoding")
    $statusDirty = $Window.FindName("statusDirty")

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
