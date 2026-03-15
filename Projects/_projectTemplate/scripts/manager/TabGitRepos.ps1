# TabGitRepos.ps1 - Git Repos tab: scan, save, and restore Git repositories

$script:GitReposScanResults = @()
$script:GitReposWindow = $null

# ---------------------------------------------------------------------------
# Helper: run a git command in a subprocess and return trimmed stdout
# ---------------------------------------------------------------------------
function Invoke-GitCommand {
    param(
        [string]$RepoPath,
        [string[]]$GitArgs
    )
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = "git"
        $psi.Arguments              = "-C `"$RepoPath`" $($GitArgs -join ' ')"
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        return $stdout.Trim()
    }
    catch {
        return ""
    }
}

# ---------------------------------------------------------------------------
# Scan development/source under a project for .git folders
# Called from within a Runspace (no AppState access)
# ---------------------------------------------------------------------------
function Find-GitReposInProject {
    param(
        [string]$ProjectPath,
        [string]$ProjectName
    )
    $results = @()
    $devSource = Join-Path $ProjectPath "development\source"
    if (-not (Test-Path $devSource)) { return $results }

    try {
        $gitDirs = Get-ChildItem -Path $devSource -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -eq ".git" }

        foreach ($gitDir in $gitDirs) {
            $repoPath = $gitDir.Parent.FullName

            # relative path from devSource
            $relative = $repoPath.Substring($devSource.Length).TrimStart('\', '/')
            if ($relative -eq "") { $relative = "." }

            $remote = Invoke-GitCommand -RepoPath $repoPath -GitArgs @("remote", "get-url", "origin")
            if ($remote -eq "") { $remote = "(none)" }

            $branch = Invoke-GitCommand -RepoPath $repoPath -GitArgs @("branch", "--show-current")
            if ($branch -eq "") { $branch = "?" }

            $lastDate = Invoke-GitCommand -RepoPath $repoPath -GitArgs @("log", "-1", "--format=%cd", "--date=short")
            if ($lastDate -eq "") { $lastDate = "-" }

            $results += @{
                name         = Split-Path $repoPath -Leaf
                relativePath = $relative
                fullPath     = $repoPath
                remoteOrigin = $remote
                branch       = $branch
                lastCommitDate = $lastDate
                projectName  = $ProjectName
            }
        }
    }
    catch {
        # return whatever we found so far
    }
    return $results
}

# ---------------------------------------------------------------------------
# Render results into the entries panel
# ---------------------------------------------------------------------------
function Render-GitReposList {
    param($Results, [System.Windows.Window]$Window)

    $panel = $Window.FindName("gitReposEntriesPanel")
    if ($null -eq $panel) { return }
    $panel.Children.Clear()

    $c = Get-ThemeColors -ThemeName $script:AppState.Theme

    if ($Results.Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text       = "No Git repositories found."
        $tb.Foreground = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($c.Subtext0)
        $tb.Margin     = [System.Windows.Thickness]::new(8, 12, 8, 4)
        $panel.Children.Add($tb) | Out-Null
        return
    }

    $script:GitReposScanResults = $Results

    foreach ($repo in $Results) {
        $row = New-GitRepoRow -Repo $repo -Colors $c
        $panel.Children.Add($row) | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Build a single repo row (Border > Grid with 5 columns)
# ---------------------------------------------------------------------------
function New-GitRepoRow {
    param($Repo, $Colors)

    $surface0 = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Surface0)
    $surface1 = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Surface1)

    $border = New-Object System.Windows.Controls.Border
    $border.Background   = $surface0
    $border.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $border.Margin       = [System.Windows.Thickness]::new(0, 0, 0, 2)
    $border.Padding      = [System.Windows.Thickness]::new(8, 5, 8, 5)
    $border.Tag          = $Repo

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($w in @(120, 160, [double]::NaN, 80, 110)) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        if ([double]::IsNaN($w)) {
            $cd.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        } else {
            $cd.Width = [System.Windows.GridLength]::new($w)
        }
        $grid.ColumnDefinitions.Add($cd)
    }

    # Col 0: ProjectName
    $tbProj = New-Object System.Windows.Controls.TextBlock
    $tbProj.Text = $Repo.projectName
    $tbProj.Foreground = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Subtext0)
    $tbProj.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tbProj.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($tbProj, 0)
    $grid.Children.Add($tbProj) | Out-Null

    # Col 1: Repo name (bold)
    $tbName = New-Object System.Windows.Controls.TextBlock
    $tbName.Text = $Repo.name
    $tbName.FontWeight = [System.Windows.FontWeights]::Bold
    $tbName.Foreground = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Text)
    $tbName.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tbName.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($tbName, 1)
    $grid.Children.Add($tbName) | Out-Null

    # Col 2: Remote URL (Blue, trimmed)
    $tbRemote = New-Object System.Windows.Controls.TextBlock
    $tbRemote.Text = $Repo.remoteOrigin
    $tbRemote.Foreground = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Blue)
    $tbRemote.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tbRemote.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $tbRemote.Margin = [System.Windows.Thickness]::new(8, 0, 8, 0)
    [System.Windows.Controls.Grid]::SetColumn($tbRemote, 2)
    $grid.Children.Add($tbRemote) | Out-Null

    # Col 3: Branch (Green)
    $tbBranch = New-Object System.Windows.Controls.TextBlock
    $tbBranch.Text = $Repo.branch
    $tbBranch.Foreground = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Green)
    $tbBranch.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tbBranch.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($tbBranch, 3)
    $grid.Children.Add($tbBranch) | Out-Null

    # Col 4: Last commit date (Subtext1)
    $tbDate = New-Object System.Windows.Controls.TextBlock
    $tbDate.Text = $Repo.lastCommitDate
    $tbDate.Foreground = [System.Windows.Media.SolidColorBrush][System.Windows.Media.ColorConverter]::ConvertFromString($Colors.Subtext1)
    $tbDate.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tbDate.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    [System.Windows.Controls.Grid]::SetColumn($tbDate, 4)
    $grid.Children.Add($tbDate) | Out-Null

    $border.Child = $grid

    # Hover highlight
    $border.Add_MouseEnter({
        $this.Background = $surface1
    })
    $border.Add_MouseLeave({
        $this.Background = $surface0
    })

    return $border
}

# ---------------------------------------------------------------------------
# Helper: resolve ComboBox display name to a ProjectInfo object
# Falls back to Get-ProjectInfoList if AppState.Projects is not yet populated
# ---------------------------------------------------------------------------
function Resolve-GitReposProject {
    param([string]$ComboText)
    $params = Get-ProjectParams -ComboText $ComboText -MiniChecked $false
    $proj = $script:AppState.Projects | Where-Object { $_.Name -eq $params.Name } | Select-Object -First 1
    if ($null -eq $proj) {
        # AppState.Projects not yet populated -- trigger discovery now
        $all  = Get-ProjectInfoList -SkipTokens
        $proj = $all | Where-Object { $_.Name -eq $params.Name } | Select-Object -First 1
    }
    return $proj
}

# ---------------------------------------------------------------------------
# Scan button handler: runs git scan in background Runspace
# ---------------------------------------------------------------------------
function Start-GitReposScan {
    param([System.Windows.Window]$Window)

    $statusTb = $Window.FindName("gitReposStatus")
    $scanBtn  = $Window.FindName("gitReposScanBtn")
    $saveBtn  = $Window.FindName("gitReposSaveBtn")
    $copyBtn  = $Window.FindName("gitReposCopyCloneBtn")
    $combo    = $Window.FindName("gitReposProjectCombo")

    if ($null -eq $combo -or $combo.SelectedItem -eq $null) {
        if ($null -ne $statusTb) { $statusTb.Text = "Select a project first." }
        return
    }

    $selectedName = $combo.SelectedItem.ToString()
    $proj = Resolve-GitReposProject -ComboText $selectedName
    if ($null -eq $proj) {
        if ($null -ne $statusTb) { $statusTb.Text = "Project not found: $selectedName" }
        return
    }

    $projPath = $proj.Path
    $projName = $proj.Name

    if ($null -ne $statusTb)  { $statusTb.Text = "Scanning..." }
    if ($null -ne $scanBtn)   { $scanBtn.IsEnabled = $false }
    if ($null -ne $saveBtn)   { $saveBtn.IsEnabled = $false }
    if ($null -ne $copyBtn)   { $copyBtn.IsEnabled = $false }

    # Clear previous results
    $panel = $Window.FindName("gitReposEntriesPanel")
    if ($null -ne $panel) { $panel.Children.Clear() }
    $script:GitReposScanResults = @()

    # Synchronized result container
    $syncObj = [hashtable]::Synchronized(@{
        Completed = $false
        Results   = @()
        Error     = ""
    })

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = [System.Threading.ApartmentState]::STA
    $rs.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('_projPath', $projPath)
    $rs.SessionStateProxy.SetVariable('_projName', $projName)
    $rs.SessionStateProxy.SetVariable('_syncObj',  $syncObj)

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs

    $ps.AddScript({
        function Invoke-GitCommand {
            param([string]$RepoPath, [string[]]$GitArgs)
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName               = "git"
                $psi.Arguments              = "-C `"$RepoPath`" $($GitArgs -join ' ')"
                $psi.UseShellExecute        = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError  = $true
                $psi.CreateNoWindow         = $true
                $proc = [System.Diagnostics.Process]::Start($psi)
                $out  = $proc.StandardOutput.ReadToEnd()
                $proc.WaitForExit()
                return $out.Trim()
            }
            catch { return "" }
        }

        $devSource = Join-Path $_projPath "development\source"
        if (-not (Test-Path $devSource)) { return }

        try {
            $gitDirs = Get-ChildItem -Path $devSource -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -eq ".git" }
            foreach ($gd in $gitDirs) {
                $rp       = $gd.Parent.FullName
                $relative = $rp.Substring($devSource.Length).TrimStart('\','/')
                if ($relative -eq "") { $relative = "." }

                $remote = Invoke-GitCommand -RepoPath $rp -GitArgs @("remote","get-url","origin")
                if ($remote -eq "") { $remote = "(none)" }

                $branch = Invoke-GitCommand -RepoPath $rp -GitArgs @("branch","--show-current")
                if ($branch -eq "") { $branch = "?" }

                $lastDate = Invoke-GitCommand -RepoPath $rp -GitArgs @("log","-1","--format=%cd","--date=short")
                if ($lastDate -eq "") { $lastDate = "-" }

                Write-Output @{
                    name           = Split-Path $rp -Leaf
                    relativePath   = $relative
                    fullPath       = $rp
                    remoteOrigin   = $remote
                    branch         = $branch
                    lastCommitDate = $lastDate
                    projectName    = $_projName
                }
            }
        }
        catch { }
    }) | Out-Null

    $asyncHandle = $ps.BeginInvoke()

    # Poll on UI thread via DispatcherTimer
    $pollTimer = New-Object System.Windows.Threading.DispatcherTimer
    $pollTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $pollTimer.Tag = @{
        PS       = $ps
        RS       = $rs
        Handle   = $asyncHandle
        Window   = $Window
        ProjName = $projName
    }
    $pollTimer.Add_Tick({
        param($sender, $e)
        $d = $sender.Tag
        if (-not $d.Handle.IsCompleted) { return }
        $sender.Stop()

        try {
            $res = @($d.PS.EndInvoke($d.Handle))
            Render-GitReposList -Results $res -Window $d.Window

            $saveBtn2  = $d.Window.FindName("gitReposSaveBtn")
            $copyBtn2  = $d.Window.FindName("gitReposCopyCloneBtn")
            $statusTb2 = $d.Window.FindName("gitReposStatus")
            $scanBtn2  = $d.Window.FindName("gitReposScanBtn")

            if ($null -ne $scanBtn2)  { $scanBtn2.IsEnabled  = $true }
            if ($null -ne $saveBtn2)  { $saveBtn2.IsEnabled  = ($res.Count -gt 0) }
            if ($null -ne $copyBtn2)  { $copyBtn2.IsEnabled  = ($res.Count -gt 0) }
            if ($null -ne $statusTb2) {
                $statusTb2.Text = "Found $($res.Count) repos in $($d.ProjName)"
            }
        }
        catch {
            $scanBtn3 = $d.Window.FindName("gitReposScanBtn")
            if ($null -ne $scanBtn3) { $scanBtn3.IsEnabled = $true }
            $statusTb3 = $d.Window.FindName("gitReposStatus")
            if ($null -ne $statusTb3) { $statusTb3.Text = "Scan error: $($_.Exception.Message)" }
        }
        finally {
            $d.PS.Dispose()
            $d.RS.Close()
            $d.RS.Dispose()
        }
    }.GetNewClosure())
    $pollTimer.Start()
}

# ---------------------------------------------------------------------------
# Save to BOX: writes git_repos.json into project's shared/ folder
# ---------------------------------------------------------------------------
function Save-GitReposToBox {
    param([System.Windows.Window]$Window)

    if ($script:GitReposScanResults.Count -eq 0) {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Nothing to save. Run Scan first." }
        return
    }

    $combo = $Window.FindName("gitReposProjectCombo")
    if ($null -eq $combo -or $null -eq $combo.SelectedItem) { return }

    $proj = Resolve-GitReposProject -ComboText $combo.SelectedItem.ToString()
    if ($null -eq $proj) { return }

    $sharedPath = Join-Path $proj.Path "shared"
    if (-not (Test-Path $sharedPath)) {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "shared/ not found for $($proj.Name)" }
        return
    }

    $localRoot = [System.Environment]::ExpandEnvironmentVariables(
        $script:AppState.PathsConfig.localProjectsRoot).TrimEnd('\','/')

    $reposToSave = $script:GitReposScanResults | ForEach-Object {
        $relFull = $_.fullPath
        if ($relFull.StartsWith($localRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relFull = $relFull.Substring($localRoot.Length).TrimStart('\','/')
        }
        @{
            name           = $_.name
            relativePath   = $_.relativePath
            relPath        = $relFull
            remoteOrigin   = $_.remoteOrigin
            branch         = $_.branch
            lastCommitDate = $_.lastCommitDate
            projectName    = $_.projectName
        }
    }

    $payload = [PSCustomObject]@{
        savedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        machine = $env:COMPUTERNAME
        repos   = $reposToSave
    }

    $outPath = Join-Path $sharedPath "git_repos.json"
    try {
        $json = ConvertTo-Json -InputObject $payload -Depth 5
        [System.IO.File]::WriteAllText($outPath, $json, [System.Text.Encoding]::UTF8)
        $count = $script:GitReposScanResults.Count
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Saved to shared/git_repos.json ($count repos)" }
    }
    catch {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Save failed: $($_.Exception.Message)" }
    }
}

# ---------------------------------------------------------------------------
# Copy clone script to clipboard
# ---------------------------------------------------------------------------
function Copy-GitCloneScript {
    param([System.Windows.Window]$Window)

    if ($script:GitReposScanResults.Count -eq 0) {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Nothing to copy. Run Scan first." }
        return
    }

    $combo = $Window.FindName("gitReposProjectCombo")
    $comboText = if ($null -ne $combo -and $null -ne $combo.SelectedItem) {
        $combo.SelectedItem.ToString()
    } else { "Unknown" }

    $proj = Resolve-GitReposProject -ComboText $comboText

    $devSource = if ($null -ne $proj) {
        Join-Path $proj.Path "development\source"
    } else { "." }

    $today    = Get-Date -Format "yyyy-MM-dd"
    $lines    = @()
    $projLabel = if ($null -ne $proj) { $proj.Name } else { $comboText }
    $lines   += "# Git repos restore script: $projLabel"
    $lines   += "# Generated: $today on $env:COMPUTERNAME"
    $lines   += "cd `"$devSource`""

    foreach ($repo in $script:GitReposScanResults) {
        if ($repo.remoteOrigin -ne "(none)" -and $repo.remoteOrigin -ne "") {
            # Determine target subdirectory
            if ($repo.relativePath -eq ".") {
                $lines += "git clone $($repo.remoteOrigin)"
            } else {
                $parent = Split-Path $repo.relativePath -Parent
                if ($parent -ne "" -and $parent -ne ".") {
                    $lines += "cd `"$parent`""
                }
                $lines += "git clone $($repo.remoteOrigin)"
            }
        }
    }

    $script = $lines -join "`r`n"
    try {
        [System.Windows.Clipboard]::SetText($script)
        $count = $script:GitReposScanResults.Count
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Clone script copied to clipboard ($count repos)" }
    }
    catch {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Clipboard error: $($_.Exception.Message)" }
    }
}

# ---------------------------------------------------------------------------
# Load from BOX: reads git_repos.json saved by another PC
# ---------------------------------------------------------------------------
function Load-GitReposFromBox {
    param([System.Windows.Window]$Window)

    $combo = $Window.FindName("gitReposProjectCombo")
    if ($null -eq $combo -or $null -eq $combo.SelectedItem) {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Select a project first." }
        return
    }

    $proj = Resolve-GitReposProject -ComboText $combo.SelectedItem.ToString()
    if ($null -eq $proj) {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Project not found." }
        return
    }

    $jsonPath = Join-Path $proj.Path "shared\git_repos.json"
    if (-not (Test-Path $jsonPath)) {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "git_repos.json not found in shared/." }
        return
    }

    try {
        $localRoot = [System.Environment]::ExpandEnvironmentVariables(
            $script:AppState.PathsConfig.localProjectsRoot).TrimEnd('\','/')

        $raw     = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)
        $payload = $raw | ConvertFrom-Json
        $repos   = @($payload.repos | ForEach-Object {
            # relPath (new format) を優先、なければ fullPath をそのまま使う (旧フォーマット互換)
            $fp = if ($_.PSObject.Properties["relPath"] -and $_.relPath) {
                Join-Path $localRoot $_.relPath
            } else {
                $_.fullPath
            }
            @{
                name           = $_.name
                relativePath   = $_.relativePath
                fullPath       = $fp
                remoteOrigin   = $_.remoteOrigin
                branch         = $_.branch
                lastCommitDate = $_.lastCommitDate
                projectName    = $_.projectName
            }
        })

        Render-GitReposList -Results $repos -Window $Window

        $saveBtn = $Window.FindName("gitReposSaveBtn")
        $copyBtn = $Window.FindName("gitReposCopyCloneBtn")
        if ($null -ne $saveBtn) { $saveBtn.IsEnabled = ($repos.Count -gt 0) }
        if ($null -ne $copyBtn) { $copyBtn.IsEnabled = ($repos.Count -gt 0) }

        $savedAt = if ($payload.PSObject.Properties["savedAt"]) { $payload.savedAt } else { "?" }
        $machine = if ($payload.PSObject.Properties["machine"])  { $payload.machine }  else { "?" }

        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) {
            $st.Text = "Loaded $($repos.Count) repos from BOX (saved $savedAt on $machine)"
        }
    }
    catch {
        $st = $Window.FindName("gitReposStatus")
        if ($null -ne $st) { $st.Text = "Load error: $($_.Exception.Message)" }
    }
}

# ---------------------------------------------------------------------------
# Initialize-TabGitRepos: called from project_manager.ps1 after window load
# ---------------------------------------------------------------------------
function Initialize-TabGitRepos {
    param([System.Windows.Window]$Window)

    $script:GitReposWindow = $Window

    # Populate project combo
    $combo = $Window.FindName("gitReposProjectCombo")
    if ($null -ne $combo) {
        $combo.Items.Clear()
        foreach ($p in (Get-ProjectNameList)) {
            $combo.Items.Add($p) | Out-Null
        }
        if ($combo.Items.Count -gt 0) {
            $combo.SelectedIndex = 0
        }
    }

    # Scan button
    $scanBtn = $Window.FindName("gitReposScanBtn")
    if ($null -ne $scanBtn) {
        $scanBtn.Add_Click({
            try {
                Start-GitReposScan -Window $script:GitReposWindow
            }
            catch {
                $st = $script:GitReposWindow.FindName("gitReposStatus")
                if ($null -ne $st) { $st.Text = "Error: $($_.Exception.Message)" }
            }
        })
    }

    # Save to BOX button
    $saveBtn = $Window.FindName("gitReposSaveBtn")
    if ($null -ne $saveBtn) {
        $saveBtn.Add_Click({
            try {
                Save-GitReposToBox -Window $script:GitReposWindow
            }
            catch {
                $st = $script:GitReposWindow.FindName("gitReposStatus")
                if ($null -ne $st) { $st.Text = "Error: $($_.Exception.Message)" }
            }
        })
    }

    # Copy Clone Script button
    $copyBtn = $Window.FindName("gitReposCopyCloneBtn")
    if ($null -ne $copyBtn) {
        $copyBtn.Add_Click({
            try {
                Copy-GitCloneScript -Window $script:GitReposWindow
            }
            catch {
                $st = $script:GitReposWindow.FindName("gitReposStatus")
                if ($null -ne $st) { $st.Text = "Error: $($_.Exception.Message)" }
            }
        })
    }

    # Load from BOX button
    $loadBtn = $Window.FindName("gitReposLoadBoxBtn")
    if ($null -ne $loadBtn) {
        $loadBtn.Add_Click({
            try {
                Load-GitReposFromBox -Window $script:GitReposWindow
            }
            catch {
                $st = $script:GitReposWindow.FindName("gitReposStatus")
                if ($null -ne $st) { $st.Text = "Error: $($_.Exception.Message)" }
            }
        })
    }
}
