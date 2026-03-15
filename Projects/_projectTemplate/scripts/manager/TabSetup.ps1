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
    $setupAlsoContextLayer = $Window.FindName("setupAlsoContextLayer")
    $setupForce = $Window.FindName("setupForce")

    # Enable/disable setupForce based on setupAlsoContextLayer state
    if ($null -ne $setupAlsoContextLayer -and $null -ne $setupForce) {
        $setupAlsoContextLayer.Add_Checked({
            $sf = $Window.FindName("setupForce")
            if ($null -ne $sf) { $sf.IsEnabled = $true }
        }).GetNewClosure()
        $setupAlsoContextLayer.Add_Unchecked({
            $sf = $Window.FindName("setupForce")
            if ($null -ne $sf) { $sf.IsEnabled = $false }
        }).GetNewClosure()
        $setupForce.IsEnabled = ($setupAlsoContextLayer.IsChecked -eq $true)
    }

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

                $configPath = Join-Path $boxRoot "$projectSubPath\external_shared_paths"
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
        }).GetNewClosure()

    $btnSetupClear.Add_Click({
            $out = $Window.FindName("txtSetupOutput")
            $out.Text = ""
        }).GetNewClosure()

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
        }).GetNewClosure()

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

            # Optionally run AI Context setup immediately after (PC-B workflow)
            $chkAlsoCtx = $Window.FindName("setupAlsoContextLayer")
            if ($chkAlsoCtx.IsChecked -eq $true) {
                $ctxScriptPath = Join-Path (Split-Path $ScriptDir) `
                    "context-compression-layer\setup_context_layer.ps1"
                if (Test-Path $ctxScriptPath) {
                    $ctxArgStr = "-ProjectName '$safeName'"
                    if ($params.IsMini) { $ctxArgStr += " -Mini" }
                    if ($params.IsDomain) { $ctxArgStr += " -Category domain" }
                    $chkForce = $Window.FindName("setupForce")
                    if ($null -ne $chkForce -and $chkForce.IsChecked -eq $true) { $ctxArgStr += " -Force" }
                    Invoke-ScriptWithOutput -ScriptPath $ctxScriptPath -ArgumentString $ctxArgStr `
                        -OutputBox $outputBox -WindowRef $Window
                }
            }

            # Refresh all dropdowns: replace [BOX] entry with plain project name
            $plainName = $params.Name
            if ($params.IsDomain -and $params.IsMini) { $plainName = "$($params.Name) [Domain][Mini]" }
            elseif ($params.IsDomain) { $plainName = "$($params.Name) [Domain]" }
            elseif ($params.IsMini) { $plainName = "$($params.Name) [Mini]" }

            $allCombos = @("setupProjectName", "checkProjectCombo", "archiveProjectCombo",
                           "convertProjectCombo", "editorProjectCombo",
                           "timelineProjectCombo")
            foreach ($comboName in $allCombos) {
                $comboCtrl = $Window.FindName($comboName)
                if ($null -eq $comboCtrl) { continue }
                # Remove [BOX] variant that matches this project
                $toRemove = @()
                for ($i = 0; $i -lt $comboCtrl.Items.Count; $i++) {
                    $item = $comboCtrl.Items[$i].ToString()
                    if ($item -match '\[BOX\]') {
                        $stripped = ($item -replace '\s+\[BOX\]$', '').Trim()
                        if ($stripped -eq $plainName) { $toRemove += $i }
                    }
                }
                for ($i = $toRemove.Count - 1; $i -ge 0; $i--) {
                    $comboCtrl.Items.RemoveAt($toRemove[$i])
                }
                # Add plain name if not already present
                $alreadyPresent = $false
                for ($i = 0; $i -lt $comboCtrl.Items.Count; $i++) {
                    if ($comboCtrl.Items[$i].ToString() -eq $plainName) { $alreadyPresent = $true; break }
                }
                if (-not $alreadyPresent) { $comboCtrl.Items.Add($plainName) | Out-Null }
            }

            # Clear dashboard cache entirely so next visit uses synchronous scan (same as restart)
            $script:ProjectInfoCache = $null
            $script:ProjectInfoCacheTime = [datetime]::MinValue
        }).GetNewClosure()
}
