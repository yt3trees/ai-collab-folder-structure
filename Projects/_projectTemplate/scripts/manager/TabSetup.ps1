# TabSetup.ps1 - Setup tab event handlers

function Initialize-TabSetup {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    $btnSetup = $Window.FindName("btnSetup")
    $btnSetupClear = $Window.FindName("btnSetupClear")
    $btnSetupBrowse = $Window.FindName("btnSetupBrowseExternalShared")

    $btnSetupClear.Add_Click({
            $out = $Window.FindName("txtSetupOutput")
            $out.Text = ""
        })

    $btnSetupBrowse.Add_Click({
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select an External Shared Folder"
            $dialog.ShowNewFolderButton = $true
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $txtExternalShared = $Window.FindName("setupExternalShared")
                if ([string]::IsNullOrWhiteSpace($txtExternalShared.Text)) {
                    $txtExternalShared.Text = $dialog.SelectedPath
                }
                else {
                    $txtExternalShared.Text += "`r`n" + $dialog.SelectedPath
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

            $tierCombo = $Window.FindName("setupTier")
            $tier = ($tierCombo.SelectedItem).Content
            
            $txtExternalShared = $Window.FindName("setupExternalShared")
            $externalShared = $txtExternalShared.Text.Trim()
            
            $safeName = $name -replace "'", "''"
            $argStr = "-ProjectName '$safeName' -Tier $tier"
            
            if (-not [string]::IsNullOrWhiteSpace($externalShared)) {
                $paths = $externalShared -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($paths.Count -gt 0) {
                    $safePaths = $paths | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }
                    $joinedPaths = $safePaths -join ","
                    $argStr += " -ExternalSharedPaths $joinedPaths"
                }
            }
            
            $scriptPath = Join-Path $ScriptDir "setup_project.ps1"

            $outputBox = $Window.FindName("txtSetupOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
