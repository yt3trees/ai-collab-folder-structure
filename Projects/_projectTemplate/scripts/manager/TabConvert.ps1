# TabConvert.ps1 - Convert Tier tab event handlers

function Initialize-TabConvert {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [string[]]$ProjectList
    )

    $convertProjectCombo = $Window.FindName("convertProjectCombo")
    $btnConvert = $Window.FindName("btnConvert")
    $btnConvertClear = $Window.FindName("btnConvertClear")

    # Populate dropdown
    foreach ($p in $ProjectList) {
        $convertProjectCombo.Items.Add($p) | Out-Null
    }

    $btnConvertClear.Add_Click({
            $out = $Window.FindName("txtConvertOutput")
            $out.Text = ""
        })

    $btnConvert.Add_Click({
            $combo = $Window.FindName("convertProjectCombo")
            $toTierCombo = $Window.FindName("convertToTier")
            $structureCombo = $Window.FindName("convertStructure")
            $dryRun = $Window.FindName("convertDryRun")

            # Parse project name (strip [Mini] prefix if present)
            $params = Get-ProjectParams -ComboText $combo.Text -MiniChecked $false
            if ([string]::IsNullOrEmpty($params.Name)) {
                [System.Windows.MessageBox]::Show(
                    "Project Name is required.",
                    "Validation",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $toTier = ($toTierCombo.SelectedItem).Content
            $structure = ($structureCombo.SelectedItem).Content

            # Confirm when not DryRun
            if (-not $dryRun.IsChecked) {
                $result = [System.Windows.MessageBox]::Show(
                    "Convert '$($params.Name)' to $toTier tier for real (not DryRun)?`nThis will move project folders between locations.",
                    "Confirm Convert",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
                )
                if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
            }

            $argStr = "-ProjectName '$($params.Name)' -To $toTier -Structure $structure -Force"
            if ($dryRun.IsChecked) { $argStr += " -DryRun" }

            $scriptPath = Join-Path $ScriptDir "convert_tier.ps1"
            $outputBox = $Window.FindName("txtConvertOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
