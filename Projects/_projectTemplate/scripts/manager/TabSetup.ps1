# TabSetup.ps1 - Setup tab event handlers

function Initialize-TabSetup {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [string[]]$ProjectList
    )

    $setupProjectCombo = $Window.FindName("setupProjectName")
    $btnSetup = $Window.FindName("btnSetup")
    $btnSetupClear = $Window.FindName("btnSetupClear")
    $btnSetupBrowse = $Window.FindName("btnSetupBrowseExternalShared")

    # Populate project dropdown
    foreach ($p in $ProjectList) {
        $setupProjectCombo.Items.Add($p) | Out-Null
    }

    # Auto-load when project selection changes
    $setupProjectCombo.Add_SelectionChanged({
            $combo = $Window.FindName("setupProjectName")
            $comboText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
            if ([string]::IsNullOrWhiteSpace($comboText)) { return }

            try {
                # Resolve boxProjectsRoot inside handler (local vars don't survive function scope)
                $wsRoot = $script:AppState.WorkspaceRoot
                $pcfg = Join-Path $wsRoot "_config\paths.json"
                if (-not (Test-Path $pcfg)) { return }
                $cfg = Get-Content $pcfg -Raw | ConvertFrom-Json
                $boxRoot = [System.Environment]::ExpandEnvironmentVariables($cfg.boxProjectsRoot)

                $params = Get-ProjectParams -ComboText $comboText -MiniChecked $false
                $categoryPrefix = if ($params.IsDomain) { "_domains\" } else { "" }
                $projectSubPath = if ($params.IsMini) {
                    "${categoryPrefix}_mini\$($params.Name)"
                }
                else {
                    "${categoryPrefix}$($params.Name)"
                }

                $configPath = Join-Path $boxRoot "$projectSubPath\.external_shared_paths"
                $txtExternalShared = $Window.FindName("setupExternalShared")
                if (Test-Path $configPath) {
                    $lines = @(Get-Content -Path $configPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                    if ($lines.Count -gt 0) {
                        $txtExternalShared.Text = ($lines -join "`r`n")
                    }
                    else {
                        $txtExternalShared.Text = ""
                    }
                }
                else {
                    $txtExternalShared.Text = ""
                }
            }
            catch {
                $Window.FindName("txtSetupOutput").Text = "[Auto-load error] $($_.Exception.Message)"
            }
        })

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
            $combo = $Window.FindName("setupProjectName")
            $name = $combo.Text.Trim()
            if ([string]::IsNullOrEmpty($name)) {
                [System.Windows.MessageBox]::Show(
                    "Project Name is required.",
                    "Validation",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            # Parse project name with suffix tags
            $params = Get-ProjectParams -ComboText $name -MiniChecked $false
            $safeName = $params.Name -replace "'", "''"
            $tier = if ($params.IsMini) { "mini" } else {
                ($Window.FindName("setupTier").SelectedItem).Content
            }
            $category = if ($params.IsDomain) { "domain" } else {
                ($Window.FindName("setupCategory").SelectedItem).Content
            }

            $txtExternalShared = $Window.FindName("setupExternalShared")
            $externalShared = $txtExternalShared.Text.Trim()

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
