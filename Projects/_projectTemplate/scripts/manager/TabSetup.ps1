# TabSetup.ps1 - Setup tab event handlers

function Initialize-TabSetup {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    $btnSetup = $Window.FindName("btnSetup")
    $btnSetupClear = $Window.FindName("btnSetupClear")
    $btnSetupBrowse = $Window.FindName("btnSetupBrowseTeamShared")

    $btnSetupClear.Add_Click({
            $out = $Window.FindName("txtSetupOutput")
            $out.Text = ""
        })

    $btnSetupBrowse.Add_Click({
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select a Team Shared Folder in BOX"
            $dialog.ShowNewFolderButton = $true
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $txtTeamShared = $Window.FindName("setupTeamShared")
                if ([string]::IsNullOrWhiteSpace($txtTeamShared.Text)) {
                    $txtTeamShared.Text = $dialog.SelectedPath
                }
                else {
                    $txtTeamShared.Text += "`r`n" + $dialog.SelectedPath
                }
            }
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
            
            $txtTeamShared = $Window.FindName("setupTeamShared")
            $teamShared = $txtTeamShared.Text.Trim()
            
            $safeName = $name -replace "'", "''"
            $argStr = "-ProjectName '$safeName' -Structure $structure -Tier $tier"
            
            if (-not [string]::IsNullOrWhiteSpace($teamShared)) {
                $paths = $teamShared -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($paths.Count -gt 0) {
                    $safePaths = $paths | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }
                    $joinedPaths = $safePaths -join ","
                    $argStr += " -TeamSharedPaths $joinedPaths"
                }
            }
            
            $scriptPath = Join-Path $ScriptDir "setup_project.ps1"

            $outputBox = $Window.FindName("txtSetupOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
