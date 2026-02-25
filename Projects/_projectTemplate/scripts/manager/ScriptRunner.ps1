# ScriptRunner.ps1 - Subprocess execution helper for running project scripts

function Invoke-ScriptWithOutput {
    param(
        [string]$ScriptPath,
        [string]$ArgumentString,
        [System.Windows.Controls.TextBox]$OutputBox,
        [System.Windows.Window]$WindowRef
    )

    if ($null -eq $OutputBox) { return }

    $OutputBox.Text = ""

    try {
        $OutputBox.AppendText(">>> $ScriptPath $ArgumentString`r`n")
        $OutputBox.AppendText("---`r`n")

        # Force UI repaint before blocking
        if ($null -ne $WindowRef) {
            $WindowRef.Dispatcher.Invoke(
                [Action] {},
                [System.Windows.Threading.DispatcherPriority]::Background
            )
        }

        # Merge all streams (*>&1) so Write-Host/Write-Error are captured without
        # spawning a background-thread ScriptBlock (which causes runspace conflicts)
        $cmd = "& '$ScriptPath' $ArgumentString *>&1"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

        $process = [System.Diagnostics.Process]::Start($psi)
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()

        if ($output) { $OutputBox.AppendText($output) }
        $OutputBox.AppendText("`r`n--- Done (exit: $($process.ExitCode)) ---`r`n")
    }
    catch {
        $OutputBox.AppendText("`r`n[ERROR] $($_.Exception.Message)`r`n")
        $OutputBox.AppendText("$($_.ScriptStackTrace)`r`n")
        $OutputBox.AppendText("`r`n--- Done (error) ---`r`n")
    }

    $OutputBox.ScrollToEnd()
}

function Get-ProjectParams {
    param(
        [string]$ComboText,
        $MiniChecked
    )

    $name = $ComboText.Trim()
    $isMini = [bool]$MiniChecked
    $isDomain = $false

    # Parse suffixes: [Domain][Mini], [Domain], [Mini]
    if ($name -match '^(.+)\s+\[Domain\]\[Mini\]$') {
        $name = $Matches[1]
        $isDomain = $true
        $isMini = $true
    }
    elseif ($name -match '^(.+)\s+\[Domain\]$') {
        $name = $Matches[1]
        $isDomain = $true
    }
    elseif ($name -match '^(.+)\s+\[Mini\]$') {
        $name = $Matches[1]
        $isMini = $true
    }

    return @{ Name = $name; IsMini = $isMini; IsDomain = $isDomain }
}
