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
            Add-Type -AssemblyName PresentationFramework
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "Select a Folder (Click 'Open' to confirm)"
            $dialog.ValidateNames = $false
            $dialog.CheckFileExists = $false
            $dialog.CheckPathExists = $true
            $dialog.FileName = "Folder Selection."

            if ($dialog.ShowDialog() -eq $true) {
                $selectedPath = [System.IO.Path]::GetDirectoryName($dialog.FileName)
                if (-not [string]::IsNullOrWhiteSpace($selectedPath)) {
                    $txtExternalShared = $Window.FindName("setupExternalShared")
                    if ([string]::IsNullOrWhiteSpace($txtExternalShared.Text)) {
                        $txtExternalShared.Text = $selectedPath
                    }
                    else {
                        $txtExternalShared.Text += "`r`n" + $selectedPath
                    }
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

            $categoryCombo = $Window.FindName("setupCategory")
            $category = ($categoryCombo.SelectedItem).Content

            $txtExternalShared = $Window.FindName("setupExternalShared")
            $externalShared = $txtExternalShared.Text.Trim()

            $safeName = $name -replace "'", "''"
            $argStr = "-ProjectName '$safeName' -Tier $tier -Category $category"
            
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
