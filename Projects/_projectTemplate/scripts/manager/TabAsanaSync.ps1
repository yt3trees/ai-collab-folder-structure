# TabAsanaSync.ps1 - Asana Sync tab: manual and scheduled execution of sync_from_asana.py

$script:AsanaSyncState = @{
    Timer      = $null
    Running    = $false
    LastSync   = $null
    SyncScript = ""
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

        return $process.ExitCode
    }
    catch {
        $OutputBox.AppendText("`r`n[ERROR] $($_.Exception.Message)`r`n")
        $OutputBox.AppendText("$($_.ScriptStackTrace)`r`n")
        $OutputBox.AppendText("`r`n--- Done (error) ---`r`n")
        return -1
    }
    finally {
        $OutputBox.ScrollToEnd()
    }
}

function Initialize-TabAsanaSync {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    $btnSync = $Window.FindName("btnAsanaSync")
    $btnClear = $Window.FindName("btnAsanaClear")
    $chkSchedule = $Window.FindName("chkAsanaSchedule")
    $txtInterval = $Window.FindName("txtAsanaInterval")
    $lblLastSync = $Window.FindName("lblAsanaLastSync")
    $txtOutput = $Window.FindName("txtAsanaOutput")

    # Path to sync_from_asana.py (stored in script-scope for event handler access)
    $globalScriptsDir = Join-Path (Split-Path (Split-Path $ScriptDir)) "_globalScripts"
    $script:AsanaSyncState.SyncScript = Join-Path $globalScriptsDir "sync_from_asana.py"

    # --- Manual sync button ---
    $btnSync.Add_Click({
            $txtOutput = $Window.FindName("txtAsanaOutput")
            $btnSync = $Window.FindName("btnAsanaSync")
            $lblLastSync = $Window.FindName("lblAsanaLastSync")

            if ($script:AsanaSyncState.Running) {
                $txtOutput.AppendText("[INFO] Sync is already running.`r`n")
                $txtOutput.ScrollToEnd()
                return
            }

            if (-not (Test-Path $script:AsanaSyncState.SyncScript)) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.Text = "Error: sync_from_asana.py not found at:`n$($script:AsanaSyncState.SyncScript)"
                return
            }

            $script:AsanaSyncState.Running = $true
            $btnSync.IsEnabled = $false
            $btnSync.Content = "Syncing..."

            $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1")
            )

            $exitCode = Invoke-PythonScriptWithOutput -ScriptPath $script:AsanaSyncState.SyncScript `
                -OutputBox $txtOutput -WindowRef $Window

            $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $script:AsanaSyncState.LastSync = $now
            $lblLastSync.Text = $now

            $script:AsanaSyncState.Running = $false
            $btnSync.IsEnabled = $true
            $btnSync.Content = "Run Sync Now"
        })

    # --- Clear button ---
    $btnClear.Add_Click({
            $Window.FindName("txtAsanaOutput").Text = ""
        })

    # --- Schedule checkbox ---
    $chkSchedule.Add_Checked({
            $txtInterval = $Window.FindName("txtAsanaInterval")
            $txtOutput = $Window.FindName("txtAsanaOutput")
            $lblLastSync = $Window.FindName("lblAsanaLastSync")
            $btnSync = $Window.FindName("btnAsanaSync")

            $intervalMin = 0
            if (-not [int]::TryParse($txtInterval.Text, [ref]$intervalMin) -or $intervalMin -lt 1) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.AppendText("[ERROR] Invalid interval. Enter a positive integer (minutes).`r`n")
                $txtOutput.ScrollToEnd()
                $Window.FindName("chkAsanaSchedule").IsChecked = $false
                return
            }

            # Create DispatcherTimer
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMinutes($intervalMin)
            $timer.Add_Tick({
                    $txtOutput = $Window.FindName("txtAsanaOutput")
                    $btnSync = $Window.FindName("btnAsanaSync")
                    $lblLastSync = $Window.FindName("lblAsanaLastSync")

                    if ($script:AsanaSyncState.Running) { return }

                    $txtOutput.AppendText("`r`n=== Scheduled Sync ===`r`n")

                    $script:AsanaSyncState.Running = $true
                    $btnSync.IsEnabled = $false
                    $btnSync.Content = "Syncing..."

                    $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1")
                    )

                    $exitCode = Invoke-PythonScriptWithOutput -ScriptPath $script:AsanaSyncState.SyncScript `
                        -OutputBox $txtOutput -WindowRef $Window

                    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $script:AsanaSyncState.LastSync = $now
                    $lblLastSync.Text = $now

                    $script:AsanaSyncState.Running = $false
                    $btnSync.IsEnabled = $true
                    $btnSync.Content = "Run Sync Now"
                })
            $timer.Start()
            $script:AsanaSyncState.Timer = $timer

            $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1")
            )
            $txtOutput.AppendText("[SCHEDULE] Timer started: every $intervalMin min`r`n")
            $txtOutput.ScrollToEnd()
        })

    $chkSchedule.Add_Unchecked({
            $txtOutput = $Window.FindName("txtAsanaOutput")

            if ($null -ne $script:AsanaSyncState.Timer) {
                $script:AsanaSyncState.Timer.Stop()
                $script:AsanaSyncState.Timer = $null
            }

            $txtOutput.AppendText("[SCHEDULE] Timer stopped.`r`n")
            $txtOutput.ScrollToEnd()
        })
}
