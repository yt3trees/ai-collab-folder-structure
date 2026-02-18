# TabSetup.ps1 - Setup tab event handlers

function Initialize-TabSetup {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    $btnSetup = $Window.FindName("btnSetup")
    $btnSetupClear = $Window.FindName("btnSetupClear")

    $btnSetupClear.Add_Click({
            $out = $Window.FindName("txtSetupOutput")
            $out.Text = ""
        })

    $btnSetup.Add_Click({
            $projNameBox = $Window.FindName("setupProjectName")
            $name = $projNameBox.Text.Trim()
            if ([string]::IsNullOrEmpty($name)) {
                [System.Windows.MessageBox]::Show(
                    "Project Name is required.",
                    "Validation",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $structureCombo = $Window.FindName("setupStructure")
            $tierCombo = $Window.FindName("setupTier")
            $structure = ($structureCombo.SelectedItem).Content
            $tier = ($tierCombo.SelectedItem).Content
            $argStr = "-ProjectName '$name' -Structure $structure -Tier $tier"
            $scriptPath = Join-Path $ScriptDir "setup_project.ps1"

            $outputBox = $Window.FindName("txtSetupOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
