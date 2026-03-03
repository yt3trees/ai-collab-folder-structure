# TabArchive.ps1 - Archive tab event handlers

function Initialize-TabArchive {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [string[]]$ProjectList
    )

    $archiveProjectCombo = $Window.FindName("archiveProjectCombo")
    $btnArchive = $Window.FindName("btnArchive")
    $btnArchiveClear = $Window.FindName("btnArchiveClear")
    $archiveMini = $Window.FindName("archiveMini")
    $archiveDomain = $Window.FindName("archiveDomain")

    # Populate dropdown
    foreach ($p in $ProjectList) {
        $archiveProjectCombo.Items.Add($p) | Out-Null
    }

    # Auto-toggle checkboxes on combo selection
    $archiveProjectCombo.Add_SelectionChanged({
            $combo = $Window.FindName("archiveProjectCombo")
            $comboText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
            if ([string]::IsNullOrWhiteSpace($comboText)) { return }

            $params = Get-ProjectParams -ComboText $comboText -MiniChecked $false -DomainChecked $false
            $Window.FindName("archiveMini").IsChecked = $params.IsMini
            $Window.FindName("archiveDomain").IsChecked = $params.IsDomain
        })

    $btnArchiveClear.Add_Click({
            $out = $Window.FindName("txtArchiveOutput")
            $out.Text = ""
        })

    $btnArchive.Add_Click({
            $combo = $Window.FindName("archiveProjectCombo")
            $mini = $Window.FindName("archiveMini")
            $domain = $Window.FindName("archiveDomain")
            $dryRun = $Window.FindName("archiveDryRun")
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

            # Confirm when not DryRun
            if (-not $dryRun.IsChecked) {
                $result = [System.Windows.MessageBox]::Show(
                    "Archive '$($params.Name)' for real (not DryRun)?`nThis will move project folders to _archive/.",
                    "Confirm Archive",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
                )
                if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
            }

            $safeName = $params.Name -replace "'", "''"
            $argStr = "-ProjectName '$safeName' -Force"
            if ($params.IsMini) { $argStr += " -Mini" }
            if ($params.IsDomain) { $argStr += " -Category domain" }
            if ($dryRun.IsChecked) { $argStr += " -DryRun" }

            $scriptPath = Join-Path $ScriptDir "archive_project.ps1"
            $outputBox = $Window.FindName("txtArchiveOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
