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
    $checkMini = $Window.FindName("checkMini")
    $checkDomain = $Window.FindName("checkDomain")

    # Populate dropdown
    foreach ($p in $ProjectList) {
        $checkProjectCombo.Items.Add($p) | Out-Null
    }

    # Auto-toggle checkboxes on combo selection
    $checkProjectCombo.Add_SelectionChanged({
            $combo = $Window.FindName("checkProjectCombo")
            $comboText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
            if ([string]::IsNullOrWhiteSpace($comboText)) { return }

            $params = Get-ProjectParams -ComboText $comboText -MiniChecked $false -DomainChecked $false
            $Window.FindName("checkMini").IsChecked = $params.IsMini
            $Window.FindName("checkDomain").IsChecked = $params.IsDomain
        })

    $btnCheckClear.Add_Click({
            $out = $Window.FindName("txtCheckOutput")
            $out.Text = ""
        })

    $btnCheck.Add_Click({
            $combo = $Window.FindName("checkProjectCombo")
            $mini = $Window.FindName("checkMini")
            $domain = $Window.FindName("checkDomain")
            $params = Get-ProjectParams -ComboText $combo.Text `
                -MiniChecked $mini.IsChecked -DomainChecked $domain.IsChecked
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
            if ($params.IsDomain) { $argStr += " -Category domain" }

            $scriptPath = Join-Path $ScriptDir "check_project.ps1"
            $outputBox = $Window.FindName("txtCheckOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
