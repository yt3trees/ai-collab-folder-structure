# ScriptRunner.ps1 - Subprocess execution helper for running project scripts

function Invoke-ScriptWithOutput {
    param(
        [string]$ScriptPath,
        [string]$ArgumentString,
        [System.Windows.Controls.TextBox]$OutputBox,
        [System.Windows.Window]$WindowRef
    )

    $OutputBox.Text = ""
    $OutputBox.AppendText(">>> $ScriptPath $ArgumentString`r`n")
    $OutputBox.AppendText("---`r`n")

    # Force UI repaint before blocking
    if ($null -ne $WindowRef) {
        $WindowRef.Dispatcher.Invoke(
            [Action] {},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    }

    try {
        $cmd = "& '$ScriptPath' $ArgumentString"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($stdout) { $OutputBox.AppendText($stdout) }
        if ($stderr) { $OutputBox.AppendText($stderr) }
    }
    catch {
        $OutputBox.AppendText("`r`n[ERROR] $($_.Exception.Message)`r`n")
    }

    $OutputBox.AppendText("`r`n--- Done ---`r`n")
    $OutputBox.ScrollToEnd()
}

function Get-ProjectParams {
    param(
        [string]$ComboText,
        $MiniChecked
    )

    $name = $ComboText.Trim()
    $isMini = [bool]$MiniChecked

    if ($name -match '^\[Mini\]\s+(.+)$') {
        $name = $Matches[1]
        $isMini = $true
    }

    return @{ Name = $name; IsMini = $isMini }
}
