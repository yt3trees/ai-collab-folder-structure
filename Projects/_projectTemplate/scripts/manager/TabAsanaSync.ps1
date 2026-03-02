# TabAsanaSync.ps1 - Asana Sync tab: manual and scheduled execution of sync_from_asana.py

$script:AsanaSyncState = @{
    Timer      = $null
    Running    = $false
    LastSync   = $null
    SyncScript = ""
    Window     = $null
    Restoring  = $false
}

function Invoke-PythonScriptWithOutput {
    param(
        [string]$ScriptPath,
        [System.Windows.Controls.TextBox]$OutputBox,
        [System.Windows.Window]$WindowRef
    )

    if ($null -eq $OutputBox) { return }

    try {
        $OutputBox.AppendText(">>> python $ScriptPath`r`n")
        $OutputBox.AppendText("---`r`n")

        # Force UI repaint before blocking
        if ($null -ne $WindowRef) {
            $WindowRef.Dispatcher.Invoke(
                [Action] {},
                [System.Windows.Threading.DispatcherPriority]::Background
            )
        }

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

        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($stdout) { $OutputBox.AppendText($stdout) }
        if ($stderr) {
            $OutputBox.AppendText("`r`n[STDERR]`r`n$stderr")
        }
        $OutputBox.AppendText("`r`n--- Done (exit: $($process.ExitCode)) ---`r`n")
    }
    catch {
        $OutputBox.AppendText("`r`n[ERROR] $($_.Exception.Message)`r`n")
        $OutputBox.AppendText("$($_.ScriptStackTrace)`r`n")
        $OutputBox.AppendText("`r`n--- Done (error) ---`r`n")
    }
    finally {
        $OutputBox.ScrollToEnd()
    }
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

    Invoke-PythonScriptWithOutput -ScriptPath $script:AsanaSyncState.SyncScript `
        -OutputBox $txtOutput -WindowRef $w

    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $script:AsanaSyncState.LastSync = $now
    if ($null -ne $lblLastSync) { $lblLastSync.Text = $now }

    $script:AsanaSyncState.Running = $false
    if ($null -ne $btnSync) {
        $btnSync.IsEnabled = $true
        $btnSync.Content = "Run Sync Now"
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
    }
}
