# TabCheck.ps1 - Check tab event handlers

function Initialize-TabCheck {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [string[]]$ProjectList
    )

    $checkProjectCombo = $Window.FindName("checkProjectCombo")
    $btnCheck = $Window.FindName("btnCheck")
    $btnCheckClear = $Window.FindName("btnCheckClear")

    # Populate dropdown
    foreach ($p in $ProjectList) {
        $checkProjectCombo.Items.Add($p) | Out-Null
    }

    $btnCheckClear.Add_Click({
            $out = $Window.FindName("txtCheckOutput")
            $out.Text = ""
        })

    $btnCheck.Add_Click({
            $combo = $Window.FindName("checkProjectCombo")
            $mini = $Window.FindName("checkMini")
            $params = Get-ProjectParams -ComboText $combo.Text `
                -MiniChecked $mini.IsChecked
            if ([string]::IsNullOrEmpty($params.Name)) {
                [System.Windows.MessageBox]::Show(
                    "Project Name is required.",
                    "Validation",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $safeName = $params.Name -replace "'", "''"
            $argStr = "-ProjectName '$safeName'"
            if ($params.IsMini) { $argStr += " -Mini" }

            $scriptPath = Join-Path $ScriptDir "check_project.ps1"
            $outputBox = $Window.FindName("txtCheckOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
