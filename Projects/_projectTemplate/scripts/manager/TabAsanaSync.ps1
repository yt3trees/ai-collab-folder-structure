# TabAsanaSync.ps1 - Asana Sync tab: manual and scheduled execution of sync_from_asana.py

$script:AsanaSyncState = @{
    Timer      = $null
    Running    = $false
    LastSync   = $null
    SyncScript = ""
    Window     = $null
    Restoring  = $false
}

function Invoke-PythonScriptAsync {
    param(
        [string]$ScriptPath,
        [System.Windows.Controls.TextBox]$OutputBox,
        [scriptblock]$OnComplete
    )

    if ($null -eq $OutputBox) { return }

    $OutputBox.AppendText(">>> python $ScriptPath`r`n---`r`n")
    $OutputBox.ScrollToEnd()

    # Synchronized hashtable for sharing results between runspaces
    # (Start-Job is unusable in WPF: $app.Run() blocks PS job state updates)
    $syncState = [hashtable]::Synchronized(@{
        Completed    = $false
        Stdout       = ''
        Stderr       = ''
        ExitCode     = 0
        ErrorMessage = ''
    })

    # Dedicated runspace: uses .NET ThreadPool, unaffected by WPF Dispatcher
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    $rs.SessionStateProxy.SetVariable('ScriptPath', $ScriptPath)
    $rs.SessionStateProxy.SetVariable('syncState', $syncState)

    $ps.AddScript({
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "python"
            $psi.Arguments = "`"$ScriptPath`""
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
            $psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8"

            $proc = [System.Diagnostics.Process]::Start($psi)
            $syncState.Stdout   = $proc.StandardOutput.ReadToEnd()
            $syncState.Stderr   = $proc.StandardError.ReadToEnd()
            $proc.WaitForExit()
            $syncState.ExitCode = $proc.ExitCode
        }
        catch {
            $syncState.ErrorMessage = $_.Exception.Message
            $syncState.ExitCode     = -1
        }
        $syncState.Completed = $true
    }) | Out-Null

    $ps.BeginInvoke() | Out-Null

    # DispatcherTimer polls syncState.Completed (pure .NET flag, no PS job system needed)
    $pollTimer       = New-Object System.Windows.Threading.DispatcherTimer
    $pollTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $capturedState    = $syncState
    $capturedOutput   = $OutputBox
    $capturedOnComplete = $OnComplete
    $capturedTimer    = $pollTimer
    $capturedPs       = $ps
    $capturedRs       = $rs

    $pollTimer.Add_Tick(({
        if ($capturedState.Completed) {
            $capturedTimer.Stop()
            $capturedPs.Dispose()
            $capturedRs.Dispose()

            if ($capturedState.ErrorMessage) {
                $capturedOutput.AppendText("`r`n[ERROR] $($capturedState.ErrorMessage)`r`n")
                $capturedOutput.AppendText("`r`n--- Done (error) ---`r`n")
            }
            else {
                if ($capturedState.Stdout) { $capturedOutput.AppendText($capturedState.Stdout) }
                if ($capturedState.Stderr) { $capturedOutput.AppendText("`r`n[STDERR]`r`n$($capturedState.Stderr)") }
                $capturedOutput.AppendText("`r`n--- Done (exit: $($capturedState.ExitCode)) ---`r`n")
            }
            $capturedOutput.ScrollToEnd()
            if ($null -ne $capturedOnComplete) { & $capturedOnComplete }
        }
    }).GetNewClosure())
    $pollTimer.Start()
}

# --- Config persistence (paths.json "asanaSync" property) ---

function Get-AsanaSyncConfig {
    $config = $script:AppState.PathsConfig
    $defaults = @{ Enabled = $false; IntervalMin = 60 }

    if ($null -eq $config) { return $defaults }

    $prop = $config.PSObject.Properties | Where-Object { $_.Name -eq "asanaSync" }
    if ($null -eq $prop -or $null -eq $prop.Value) { return $defaults }

    $s = $prop.Value
    return @{
        Enabled     = if ($s.PSObject.Properties["enabled"]) { $s.enabled } else { $false }
        IntervalMin = if ($s.PSObject.Properties["intervalMin"]) { $s.intervalMin } else { 60 }
    }
}

function Save-AsanaSyncConfig {
    param(
        [bool]$Enabled,
        [int]$IntervalMin
    )

    $configPath = Join-Path $script:AppState.WorkspaceRoot "_config\paths.json"
    if (-not (Test-Path $configPath)) { return $false }

    try {
        # Detect encoding: try UTF-8 BOM first, then UTF-8, then cp932 (SJIS)
        $rawBytes = [System.IO.File]::ReadAllBytes($configPath)
        $detectedEncoding = [System.Text.Encoding]::UTF8
        if ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
            $detectedEncoding = New-Object System.Text.UTF8Encoding($true)  # UTF-8 with BOM
        }
        else {
            try {
                $testStr = [System.Text.Encoding]::UTF8.GetString($rawBytes)
                $null = $testStr | ConvertFrom-Json
                $detectedEncoding = New-Object System.Text.UTF8Encoding($false)
            }
            catch {
                $detectedEncoding = [System.Text.Encoding]::GetEncoding(932)  # cp932/SJIS
            }
        }

        $json = $detectedEncoding.GetString($rawBytes)
        # Strip BOM character if present
        if ($json.Length -gt 0 -and $json[0] -eq [char]0xFEFF) {
            $json = $json.Substring(1)
        }
        $obj = $json | ConvertFrom-Json

        $syncObj = [PSCustomObject]@{
            enabled     = $Enabled
            intervalMin = $IntervalMin
        }

        $existingProp = $obj.PSObject.Properties | Where-Object { $_.Name -eq "asanaSync" }
        if ($null -ne $existingProp) {
            $obj.asanaSync = $syncObj
        }
        else {
            $obj | Add-Member -MemberType NoteProperty -Name "asanaSync" -Value $syncObj
        }

        $newJson = $obj | ConvertTo-Json -Depth 10
        # Unescape \uXXXX sequences so non-ASCII characters (e.g. Japanese) are preserved as-is
        $newJson = [System.Text.RegularExpressions.Regex]::Replace($newJson, '\\u([0-9A-Fa-f]{4})', {
                param($m)
                [char]([int]::Parse($m.Groups[1].Value, [System.Globalization.NumberStyles]::HexNumber))
            })
        [System.IO.File]::WriteAllText($configPath, $newJson, $detectedEncoding)

        # Update in-memory config
        $existingConfigProp = $script:AppState.PathsConfig.PSObject.Properties | Where-Object { $_.Name -eq "asanaSync" }
        if ($null -ne $existingConfigProp) {
            $script:AppState.PathsConfig.asanaSync = $syncObj
        }
        else {
            $script:AppState.PathsConfig | Add-Member -MemberType NoteProperty -Name "asanaSync" -Value $syncObj
        }

        return $true
    }
    catch {
        return $false
    }
}

# --- asana_config.json helpers ---

function Get-AsanaConfigPath {
    param([string]$DisplayName, [string]$BoxRoot)

    # Strip trailing [BOX] suffix
    $name = $DisplayName -replace '\s+\[BOX\]$', ''

    if ($name -match '^(.+?)\s+\[Domain\]\[Mini\]$') {
        return Join-Path $BoxRoot "_domains\_mini\$($Matches[1])\asana_config.json"
    }
    elseif ($name -match '^(.+?)\s+\[Domain\]$') {
        return Join-Path $BoxRoot "_domains\$($Matches[1])\asana_config.json"
    }
    elseif ($name -match '^(.+?)\s+\[Mini\]$') {
        return Join-Path $BoxRoot "_mini\$($Matches[1])\asana_config.json"
    }
    else {
        return Join-Path $BoxRoot "$name\asana_config.json"
    }
}

function Load-AsanaProjectConfig {
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        return @{ asana_project_gids = @(); anken_aliases = @() }
    }
    try {
        $raw = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
        $obj = $raw | ConvertFrom-Json
        $gids    = if ($obj.PSObject.Properties["asana_project_gids"]) { [array]$obj.asana_project_gids } else { @() }
        $aliases = if ($obj.PSObject.Properties["anken_aliases"])       { [array]$obj.anken_aliases }       else { @() }
        return @{ asana_project_gids = $gids; anken_aliases = $aliases }
    }
    catch {
        return @{ asana_project_gids = @(); anken_aliases = @() }
    }
}

function Save-AsanaProjectConfig {
    param([string]$ConfigPath, [string[]]$GidLines, [string[]]$AliasLines)

    $gids    = @($GidLines    | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $aliases = @($AliasLines  | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

    $obj = [PSCustomObject]@{
        asana_project_gids = $gids
        anken_aliases      = $aliases
    }

    $dir = Split-Path $ConfigPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $json = $obj | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($ConfigPath, $json, [System.Text.Encoding]::UTF8)
}

# --- Shared sync logic ---

function Invoke-AsanaSync {
    $w = $script:AsanaSyncState.Window
    if ($null -eq $w) { return }

    $txtOutput = $w.FindName("txtAsanaOutput")
    $btnSync = $w.FindName("btnAsanaSync")
    $lblLastSync = $w.FindName("lblAsanaLastSync")

    if ($script:AsanaSyncState.Running) {
        if ($null -ne $txtOutput) {
            $txtOutput.AppendText("[INFO] Sync is already running.`r`n")
            $txtOutput.ScrollToEnd()
        }
        return
    }

    if (-not (Test-Path $script:AsanaSyncState.SyncScript)) {
        if ($null -ne $txtOutput) {
            $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
            )
            $txtOutput.Text = "Error: sync_from_asana.py not found at:`n$($script:AsanaSyncState.SyncScript)"
        }
        return
    }

    $script:AsanaSyncState.Running = $true
    if ($null -ne $btnSync) {
        $btnSync.IsEnabled = $false
        $btnSync.Content = "Syncing..."
    }

    if ($null -ne $txtOutput) {
        $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1")
        )
    }

    Invoke-PythonScriptAsync -ScriptPath $script:AsanaSyncState.SyncScript `
        -OutputBox $txtOutput `
        -OnComplete {
            $w = $script:AsanaSyncState.Window
            $lblLastSync = $w.FindName("lblAsanaLastSync")
            $btnSync = $w.FindName("btnAsanaSync")

            $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $script:AsanaSyncState.LastSync = $now
            if ($null -ne $lblLastSync) { $lblLastSync.Text = $now }

            $script:AsanaSyncState.Running = $false
            if ($null -ne $btnSync) {
                $btnSync.IsEnabled = $true
                $btnSync.Content = "Run Sync Now"
            }
        }
}

# --- Tab initialization ---

function Initialize-TabAsanaSync {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    # Store references in script-scope for event handler access
    $script:AsanaSyncState.Window = $Window
    $globalScriptsDir = Join-Path (Split-Path (Split-Path $ScriptDir)) "_globalScripts"
    $script:AsanaSyncState.SyncScript = Join-Path $globalScriptsDir "sync_from_asana.py"

    # Load saved config
    $savedConfig = Get-AsanaSyncConfig

    # Set UI from saved config
    $txtInterval = $Window.FindName("txtAsanaInterval")
    $txtInterval.Text = [string]$savedConfig.IntervalMin

    # --- Create DispatcherTimer at init time ---
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMinutes($savedConfig.IntervalMin)
    $timer.Add_Tick({
            $w = $script:AsanaSyncState.Window
            if ($null -ne $w) {
                $txtOutput = $w.FindName("txtAsanaOutput")
                if ($null -ne $txtOutput) {
                    $txtOutput.AppendText("`r`n=== Scheduled Sync ===`r`n")
                }
            }
            Invoke-AsanaSync
        })
    $script:AsanaSyncState.Timer = $timer

    # --- Manual sync button ---
    $btnSync = $Window.FindName("btnAsanaSync")
    $btnSync.Add_Click({
            Invoke-AsanaSync
        })

    # --- Clear button ---
    $btnClear = $Window.FindName("btnAsanaClear")
    $btnClear.Add_Click({
            $w = $script:AsanaSyncState.Window
            if ($null -ne $w) { $w.FindName("txtAsanaOutput").Text = "" }
        })

    # --- Save Schedule button ---
    $btnSaveSchedule = $Window.FindName("btnAsanaSaveSchedule")
    $btnSaveSchedule.Add_Click({
            $w = $script:AsanaSyncState.Window
            $txtInterval = $w.FindName("txtAsanaInterval")
            $chkSchedule = $w.FindName("chkAsanaSchedule")
            $txtOutput = $w.FindName("txtAsanaOutput")

            $intervalMin = 0
            if (-not [int]::TryParse($txtInterval.Text, [ref]$intervalMin) -or $intervalMin -lt 1) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.AppendText("[ERROR] Invalid interval. Enter a positive integer (minutes).`r`n")
                $txtOutput.ScrollToEnd()
                return
            }

            $enabled = [bool]$chkSchedule.IsChecked
            $saved = Save-AsanaSyncConfig -Enabled $enabled -IntervalMin $intervalMin

            # Update timer interval if running
            $script:AsanaSyncState.Timer.Interval = [TimeSpan]::FromMinutes($intervalMin)

            if ($saved) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1")
                )
                $stateText = if ($enabled) { "ON" } else { "OFF" }
                $txtOutput.AppendText("[SAVED] Schedule: $stateText, Interval: $intervalMin min`r`n")
            }
            else {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.AppendText("[ERROR] Failed to save schedule settings.`r`n")
            }
            $txtOutput.ScrollToEnd()
        })

    # --- Schedule checkbox (start/stop timer only, no save) ---
    $chkSchedule = $Window.FindName("chkAsanaSchedule")

    $chkSchedule.Add_Checked({
            $w = $script:AsanaSyncState.Window
            $txtInterval = $w.FindName("txtAsanaInterval")
            $txtOutput = $w.FindName("txtAsanaOutput")

            $intervalMin = 0
            if (-not [int]::TryParse($txtInterval.Text, [ref]$intervalMin) -or $intervalMin -lt 1) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.AppendText("[ERROR] Invalid interval. Enter a positive integer (minutes).`r`n")
                $txtOutput.ScrollToEnd()
                $w.FindName("chkAsanaSchedule").IsChecked = $false
                return
            }

            $script:AsanaSyncState.Timer.Interval = [TimeSpan]::FromMinutes($intervalMin)
            $script:AsanaSyncState.Timer.Start()

            if (-not $script:AsanaSyncState.Restoring) {
                $txtOutput.AppendText("[SCHEDULE] Timer started: every $intervalMin min`r`n")
                $txtOutput.ScrollToEnd()
            }
        })

    $chkSchedule.Add_Unchecked({
            $w = $script:AsanaSyncState.Window
            $txtOutput = $w.FindName("txtAsanaOutput")

            $script:AsanaSyncState.Timer.Stop()

            $txtOutput.AppendText("[SCHEDULE] Timer stopped.`r`n")
            $txtOutput.ScrollToEnd()
        })

    # --- Restore schedule from saved config ---
    if ($savedConfig.Enabled) {
        $script:AsanaSyncState.Restoring = $true
        $chkSchedule.IsChecked = $true
        $script:AsanaSyncState.Restoring = $false

        # If schedule is enabled on startup, run initial sync immediately when window loads
        $Window.Add_Loaded({
            $w = $script:AsanaSyncState.Window
            if ($null -ne $w) {
                $txtOutput = $w.FindName("txtAsanaOutput")
                if ($null -ne $txtOutput) {
                    $txtOutput.AppendText("=== Auto Sync on Startup ===`r`n")
                }
            }
            Invoke-AsanaSync
        })
    }

    # --- asana_config.json editor ---
    $cmbProject    = $Window.FindName("cmbAsanaConfigProject")
    $btnLoad       = $Window.FindName("btnAsanaConfigLoad")
    $btnSaveConfig = $Window.FindName("btnAsanaConfigSave")
    $lblStatus     = $Window.FindName("lblAsanaConfigStatus")

    # Populate project ComboBox (plain strings, same as other tabs)
    $projectList = Get-ProjectNameList
    foreach ($p in $projectList) {
        $cmbProject.Items.Add($p) | Out-Null
    }
    if ($cmbProject.Items.Count -gt 0) { $cmbProject.SelectedIndex = 0 }

    # Load button: read asana_config.json and populate fields
    $btnLoad.Add_Click({
        $w    = $script:AsanaSyncState.Window
        $cmb  = $w.FindName("cmbAsanaConfigProject")
        $txtG = $w.FindName("txtAsanaConfigGids")
        $txtA = $w.FindName("txtAsanaConfigAliases")
        $lbl  = $w.FindName("lblAsanaConfigStatus")

        $displayName = if ($null -ne $cmb.SelectedItem) { $cmb.SelectedItem.ToString() } else { "" }
        if ([string]::IsNullOrWhiteSpace($displayName)) { return }

        # Resolve box path (re-read paths.json to avoid closure-scope issues)
        $wsRoot  = $script:AppState.WorkspaceRoot
        $pcfg    = Join-Path $wsRoot "_config\paths.json"
        if (-not (Test-Path $pcfg)) {
            $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8"))
            $lbl.Text = "Error: paths.json not found"
            return
        }
        $cfg     = Get-Content $pcfg -Raw | ConvertFrom-Json
        $boxRoot = [System.Environment]::ExpandEnvironmentVariables($cfg.boxProjectsRoot)
        if ([string]::IsNullOrWhiteSpace($boxRoot)) {
            $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8"))
            $lbl.Text = "Error: boxProjectsRoot not configured"
            return
        }

        $configPath = Get-AsanaConfigPath -DisplayName $displayName -BoxRoot $boxRoot

        $config = Load-AsanaProjectConfig -ConfigPath $configPath
        $txtG.Text = ($config.asana_project_gids -join "`r`n")
        $txtA.Text = ($config.anken_aliases       -join "`r`n")

        $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1"))
        $lbl.Text = if (Test-Path $configPath) { "Loaded" } else { "New file" }
    })

    # Save button: write asana_config.json
    $btnSaveConfig.Add_Click({
        $w    = $script:AsanaSyncState.Window
        $cmb  = $w.FindName("cmbAsanaConfigProject")
        $txtG = $w.FindName("txtAsanaConfigGids")
        $txtA = $w.FindName("txtAsanaConfigAliases")
        $lbl  = $w.FindName("lblAsanaConfigStatus")

        $displayName = if ($null -ne $cmb.SelectedItem) { $cmb.SelectedItem.ToString() } else { "" }
        if ([string]::IsNullOrWhiteSpace($displayName)) { return }

        # Resolve box path
        $wsRoot  = $script:AppState.WorkspaceRoot
        $pcfg    = Join-Path $wsRoot "_config\paths.json"
        if (-not (Test-Path $pcfg)) {
            $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8"))
            $lbl.Text = "Error: paths.json not found"
            return
        }
        $cfg     = Get-Content $pcfg -Raw | ConvertFrom-Json
        $boxRoot = [System.Environment]::ExpandEnvironmentVariables($cfg.boxProjectsRoot)
        if ([string]::IsNullOrWhiteSpace($boxRoot)) {
            $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8"))
            $lbl.Text = "Error: boxProjectsRoot not configured"
            return
        }

        $configPath = Get-AsanaConfigPath -DisplayName $displayName -BoxRoot $boxRoot

        try {
            $gidLines   = $txtG.Text -split "`r?`n"
            $aliasLines = $txtA.Text -split "`r?`n"
            Save-AsanaProjectConfig -ConfigPath $configPath -GidLines $gidLines -AliasLines $aliasLines
            $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1"))
            $lbl.Text = "Saved $(Get-Date -Format 'HH:mm:ss')"
        }
        catch {
            $lbl.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8"))
            $lbl.Text = "Error: $($_.Exception.Message)"
        }
    })
}
