# TabTodayQueue.ps1 - Isolated Today Queue (beta)

function Get-TodayQueueProjectDisplayName {
    param([object]$ProjectInfo)

    if ($null -eq $ProjectInfo) { return "" }
    $name = [string]$ProjectInfo.Name
    $isMini = ([string]$ProjectInfo.Tier -eq "mini")
    $isDomain = ([string]$ProjectInfo.Category -eq "domain")
    if ($isDomain -and $isMini) { return "$name [Domain][Mini]" }
    if ($isDomain) { return "$name [Domain]" }
    if ($isMini) { return "$name [Mini]" }
    return $name
}

function Get-TodayQueueTaskSourceFile {
    param([object]$ProjectInfo)

    if ($null -eq $ProjectInfo) { return $null }

    # Prefer project asana-tasks.md for task context.
    $obsidianNotes = Join-Path ([string]$ProjectInfo.AiContextPath) "obsidian_notes"
    $asanaPath = Join-Path $obsidianNotes "asana-tasks.md"
    if (Test-Path $asanaPath) { return $asanaPath }

    # Fallback to current_focus.md when available.
    if ($null -ne $ProjectInfo.FocusFile -and (Test-Path $ProjectInfo.FocusFile)) {
        return $ProjectInfo.FocusFile
    }

    return $null
}

function Get-TodayQueueAsanaToken {
    $envToken = [string]$env:ASANA_TOKEN
    if (-not [string]::IsNullOrWhiteSpace($envToken)) { return $envToken }

    $workspaceRoot = $null
    if ($script:AppState -is [hashtable] -and $script:AppState.ContainsKey("WorkspaceRoot")) {
        $workspaceRoot = [string]$script:AppState["WorkspaceRoot"]
    }
    elseif ($null -ne $script:AppState -and $null -ne $script:AppState.WorkspaceRoot) {
        $workspaceRoot = [string]$script:AppState.WorkspaceRoot
    }

    if ([string]::IsNullOrWhiteSpace($workspaceRoot)) {
        $workspaceRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot))
    }

    $configPath = Join-Path (Join-Path $workspaceRoot "_globalScripts") "config.json"
    if (-not (Test-Path $configPath)) { return "" }

    $configObj = $null
    foreach ($encName in @("utf-8", "cp932")) {
        try {
            $raw = Get-Content -Path $configPath -Raw -Encoding $encName -ErrorAction Stop
            $configObj = $raw | ConvertFrom-Json
            break
        }
        catch {
            continue
        }
    }

    if ($null -eq $configObj) { return "" }
    if ($null -eq $configObj.PSObject.Properties["asana_token"]) { return "" }
    return [string]$configObj.asana_token
}

function Invoke-TodayQueueCompleteAsanaTask {
    param(
        [string]$TaskGid,
        [string]$TaskTitle
    )

    if ([string]::IsNullOrWhiteSpace($TaskGid)) {
        return @{ Success = $false; Message = "Asana task GID is missing." }
    }

    $token = Get-TodayQueueAsanaToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        return @{ Success = $false; Message = "ASANA_TOKEN / _globalScripts/config.json の asana_token が未設定です。" }
    }

    $uri = "https://app.asana.com/api/1.0/tasks/$TaskGid"
    $bodyObj = @{ data = @{ completed = $true } }
    $body = $bodyObj | ConvertTo-Json -Depth 5

    try {
        [void](Invoke-RestMethod -Method Put `
                -Uri $uri `
                -Headers @{ Authorization = "Bearer $token" } `
                -ContentType "application/json" `
                -Body $body `
                -TimeoutSec 30 `
                -ErrorAction Stop)
        return @{ Success = $true; Message = "Asana task completed: $TaskTitle ($TaskGid)" }
    }
    catch {
        return @{ Success = $false; Message = "Asana update failed: $($_.Exception.Message)" }
    }
}

function Start-TodayQueueRefreshAfterAsanaSync {
    param([System.Windows.Window]$Window)

    if ($null -eq $Window) { return }
    if ($null -eq $script:AsanaSyncState) { return }
    if (-not $script:AsanaSyncState.ContainsKey("Running")) { return }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)

    $attempt = 0
    $maxAttempt = 180
    $targetWindow = $Window
    $capturedTimer = $timer

    $timer.Add_Tick(({
        $attempt++
        if (($script:AsanaSyncState.Running -eq $false) -or ($attempt -ge $maxAttempt)) {
            $capturedTimer.Stop()
            try { Update-TodayQueueBetaView -Window $targetWindow } catch {}
        }
    }).GetNewClosure())

    $timer.Start()
}

function Get-TodayQueueTasksFromProject {
    param([object]$ProjectInfo)

    $sourceFile = Get-TodayQueueTaskSourceFile -ProjectInfo $ProjectInfo
    if ([string]::IsNullOrWhiteSpace($sourceFile) -or -not (Test-Path $sourceFile)) { return @() }

    if ([System.IO.Path]::GetFileName($sourceFile) -ne "asana-tasks.md") {
        return @()
    }

    $lines = $null
    try {
        $lines = Get-Content $sourceFile -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        try {
            $lines = Get-Content $sourceFile -ErrorAction Stop
        }
        catch {
            return @()
        }
    }

    $projectDisplay = Get-TodayQueueProjectDisplayName -ProjectInfo $ProjectInfo
    $tasks = [System.Collections.Generic.List[hashtable]]::new()
    $inProgress = $false
    $currentParent = $null

    foreach ($line in $lines) {
        if ($line -match '^###\s*進行中') {
            $inProgress = $true
            $currentParent = $null
            continue
        }
        if ($line -match '^###\s*完了') {
            $inProgress = $false
            $currentParent = $null
            continue
        }
        if (-not $inProgress) { continue }

        # ---- Branch 1: top-level task (checked OR unchecked) ----
        if ($line -match '^\s{0,2}-\s+\[[\sx]\]\s+(.+)$') {
            $body = $Matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($body)) { continue }
            if ($body -match '^<!--\s*Memo area') { $currentParent = $null; continue }

            $dueDate = $null
            if ($body -match '\(Due:\s*(\d{4}-\d{2}-\d{2})\)') {
                try { $dueDate = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd", $null) } catch { $dueDate = $null }
            }

            $asanaUrl = $null
            $asanaTaskGid = $null
            if ($body -match '\[\[Asana\]\((https?://[^)]+)\)\]\s*$') {
                $asanaUrl = [string]$Matches[1]
                $urlWithoutQuery = ($asanaUrl -split '\?')[0].TrimEnd('/')
                if ($urlWithoutQuery -match '/(\d+)$') {
                    $asanaTaskGid = [string]$Matches[1]
                }
            }

            $title = $body -replace '\s+\[\[Asana\]\([^)]+\)\]\s*$', ''
            $title = $title -replace '\s+\(Due:\s*\d{4}-\d{2}-\d{2}\)\s*$', ''
            $title = $title -replace '^\[(担当|コラボ|他)\]\s*', ''
            if ([string]::IsNullOrWhiteSpace($title)) { $title = "(untitled task)" }

            $taskObj = @{
                ProjectDisplayName = $projectDisplay
                Title              = $title
                DueDate            = $dueDate
                StartFile          = $sourceFile
                AsanaUrl           = $asanaUrl
                AsanaTaskGid       = $asanaTaskGid
                IsSubtask          = $false
            }
            $currentParent = $taskObj

            $isUnchecked = ($line -match '^\s{0,2}-\s+\[\s\]\s+')
            if ($isUnchecked) { $tasks.Add($taskObj) | Out-Null }
            continue
        }

        # ---- Branch 2: unchecked subtask (4-space indent) ----
        if ($null -ne $currentParent -and $line -match '^\s{4}-\s+\[\s\]\s+(.+)$') {
            $body = $Matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($body)) { continue }
            if ($body -match '^<!--') { continue }

            $subDueDate = $null
            if ($body -match '\(Due:\s*(\d{4}-\d{2}-\d{2})\)') {
                try { $subDueDate = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd", $null) } catch { $subDueDate = $null }
            }
            if ($null -eq $subDueDate) { $subDueDate = $currentParent.DueDate }

            $subAsanaUrl = $null
            $subAsanaTaskGid = $null
            if ($body -match '\[\[Asana\]\((https?://[^)]+)\)\]\s*$') {
                $subAsanaUrl = [string]$Matches[1]
                $urlWithoutQuery = ($subAsanaUrl -split '\?')[0].TrimEnd('/')
                if ($urlWithoutQuery -match '/(\d+)$') {
                    $subAsanaTaskGid = [string]$Matches[1]
                }
            }

            $subTitle = $body -replace '\s+\[\[Asana\]\([^)]+\)\]\s*$', ''
            $subTitle = $subTitle -replace '\s+\(Due:\s*\d{4}-\d{2}-\d{2}\)\s*$', ''
            if ([string]::IsNullOrWhiteSpace($subTitle)) { $subTitle = "(untitled subtask)" }

            $tasks.Add(@{
                ProjectDisplayName = $currentParent.ProjectDisplayName
                Title              = $subTitle
                DueDate            = $subDueDate
                StartFile          = $currentParent.StartFile
                AsanaUrl           = $subAsanaUrl
                AsanaTaskGid       = $subAsanaTaskGid
                IsSubtask          = $true
                ParentTitle        = $currentParent.Title
            }) | Out-Null
            continue
        }
        # Other lines (blockquote >, blank lines, etc.) are skipped
    }

    return $tasks
}

function Get-TodayQueuePriority {
    param([hashtable]$Task)

    if ($null -eq $Task.DueDate) {
        return @{ Bucket = 5; Rank = 9999; Label = "No due" }
    }

    $days = [int](($Task.DueDate.Date - (Get-Date).Date).TotalDays)
    if ($days -lt 0) { return @{ Bucket = 0; Rank = [math]::Abs($days); Label = "Overdue $([math]::Abs($days))d" } }
    if ($days -eq 0) { return @{ Bucket = 1; Rank = 0; Label = "Today" } }
    if ($days -le 2) { return @{ Bucket = 2; Rank = $days; Label = "In ${days}d" } }
    if ($days -le 7) { return @{ Bucket = 3; Rank = $days; Label = "In ${days}d" } }
    return @{ Bucket = 4; Rank = $days; Label = "In ${days}d" }
}

function Select-TodayQueueProjectInEditor {
    param(
        [System.Windows.Window]$Window,
        [string]$ProjectDisplayName
    )

    $tabMain = $Window.FindName("tabMain")
    if ($null -ne $tabMain) { $tabMain.SelectedIndex = 1 }

    $combo = $Window.FindName("editorProjectCombo")
    if ($null -eq $combo) { return }

    for ($i = 0; $i -lt $combo.Items.Count; $i++) {
        if ($combo.Items[$i].ToString() -eq $ProjectDisplayName) {
            if ($combo.SelectedIndex -eq $i) { $combo.SelectedIndex = -1 }
            $combo.SelectedIndex = $i
            break
        }
    }
}

function New-TodayQueueListItem {
    param(
        [hashtable]$Task,
        [System.Windows.Window]$Window
    )

    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c0.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::Auto
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    $row.ColumnDefinitions.Add($c0) | Out-Null
    $row.ColumnDefinitions.Add($c1) | Out-Null
    $row.ColumnDefinitions.Add($c2) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = "[$($Task.ProjectDisplayName)] $($Task.Title)  |  $($Task.DueText)"
    $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.Grid]::SetColumn($label, 0)
    $row.Children.Add($label) | Out-Null

    $doneBtn = New-Object System.Windows.Controls.Button
    $doneBtn.Content = "Done"
    $doneBtn.Style = $Window.TryFindResource("SmallButton")
    $doneBtn.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
    $doneBtn.IsEnabled = -not [string]::IsNullOrWhiteSpace([string]$Task.AsanaTaskGid)
    $doneBtn.Tag = @{
        Window          = $Window
        ProjectName     = $Task.ProjectDisplayName
        TaskTitle       = $Task.Title
        TaskGid         = $Task.AsanaTaskGid
        Row             = $row
    }
    $doneBtn.Add_Click({
            param($sender, $e)
            $d = $sender.Tag
            $window = $d.Window
            $title = [string]$d.TaskTitle
            $gid = [string]$d.TaskGid
            if ([string]::IsNullOrWhiteSpace($gid)) {
                [System.Windows.MessageBox]::Show(
                    "Asana task GID が見つからないため完了処理できません。",
                    "Today Queue",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $confirm = [System.Windows.MessageBox]::Show(
                "Asanaで完了にしますか？`n[$($d.ProjectName)] $title",
                "Confirm Done",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

            $sender.IsEnabled = $false
            $result = Invoke-TodayQueueCompleteAsanaTask -TaskGid $gid -TaskTitle $title
            if (-not $result.Success) {
                $sender.IsEnabled = $true
                [System.Windows.MessageBox]::Show(
                    $result.Message,
                    "Asana Update Failed",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
                return
            }

            $status = $window.FindName("lblTodayQueueBetaStatus")
            if ($null -ne $status) {
                $status.Text = "TodayQueueBeta v3: Done synced to Asana. Running Asana Sync..."
            }

            $list = $window.FindName("lstTodayQueueBeta")
            if ($null -ne $list -and $null -ne $d.Row) {
                [void]$list.Items.Remove($d.Row)
            }

            if (Get-Command Invoke-AsanaSync -ErrorAction SilentlyContinue) {
                try {
                    Invoke-AsanaSync
                    Start-TodayQueueRefreshAfterAsanaSync -Window $window
                }
                catch {
                    if ($null -ne $status) {
                        $status.Text = "TodayQueueBeta v3: Done synced to Asana. Sync refresh failed."
                    }
                }
            }
            else {
                if ($null -ne $status) {
                    $status.Text = "TodayQueueBeta v3: Done synced to Asana. Run Asana Sync to refresh."
                }
            }
        })

    [System.Windows.Controls.Grid]::SetColumn($doneBtn, 2)
    $row.Children.Add($doneBtn) | Out-Null

    $openBtn = New-Object System.Windows.Controls.Button
    $openBtn.Content = [string][char]0x2197
    $openBtn.Style = $Window.TryFindResource("SmallButton")
    $openBtn.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
    $openBtn.ToolTip = "Open in Asana"
    if ([string]::IsNullOrWhiteSpace([string]$Task.AsanaUrl)) {
        $openBtn.Visibility = [System.Windows.Visibility]::Collapsed
    }
    else {
        $openBtn.Visibility = [System.Windows.Visibility]::Visible
    }
    $openBtn.Tag = @{ AsanaUrl = $Task.AsanaUrl }
    $openBtn.Add_Click({
        param($sender, $e)
        try {
            $url = [string]$sender.Tag.AsanaUrl
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                Start-Process $url
            }
        }
        catch {
            [System.Windows.MessageBox]::Show($_.Exception.Message, "Error") | Out-Null
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($openBtn, 1)
    $row.Children.Add($openBtn) | Out-Null

    return $row
}

function Update-TodayQueueBetaView {
    param([System.Windows.Window]$Window)

    $list = $Window.FindName("lstTodayQueueBeta")
    $status = $Window.FindName("lblTodayQueueBetaStatus")
    if ($null -eq $list -or $null -eq $status) { return }

    $list.Items.Clear()
    $status.Text = "TodayQueueBeta v3: Loading..."

    $projects = Get-ProjectInfoList -SkipTokens
    $allTasks = @()

    foreach ($p in $projects) {
        $allTasks += @(Get-TodayQueueTasksFromProject -ProjectInfo $p)
    }

    if ($allTasks.Count -eq 0) {
        $status.Text = "TodayQueueBeta v3: No in-progress tasks found."
        return
    }

    foreach ($t in $allTasks) {
        $prio = Get-TodayQueuePriority -Task $t
        $t["SortBucket"] = $prio.Bucket
        $t["SortRank"] = $prio.Rank
        $t["DueText"] = $prio.Label
    }

    $sorted = @($allTasks | Sort-Object `
            @{ Expression = { $_.SortBucket } }, `
            @{ Expression = { $_.SortRank } }, `
            @{ Expression = { $_.ProjectDisplayName } }, `
            @{ Expression = { $_.Title } })

    $showCount = [Math]::Min(100, $sorted.Count)
    for ($i = 0; $i -lt $showCount; $i++) {
        $task = $sorted[$i]
        [void]$list.Items.Add((New-TodayQueueListItem -Task $task -Window $Window))
    }

    $status.Text = "TodayQueueBeta v3: $($sorted.Count) tasks (showing $showCount)"
}

function Initialize-TabTodayQueue {
    param([System.Windows.Window]$Window)

    $btn = $Window.FindName("btnTodayQueueBetaRefresh")
    if ($null -ne $btn) {
        $btn.Add_Click({
                try {
                    Update-TodayQueueBetaView -Window $Window
                }
                catch {
                    $status = $Window.FindName("lblTodayQueueBetaStatus")
                    if ($null -ne $status) {
                        $status.Text = "TodayQueueBeta v3: Refresh failed: $($_.Exception.Message)"
                    }
                }
            }.GetNewClosure())
    }

    try {
        Update-TodayQueueBetaView -Window $Window
    }
    catch {
        $status = $Window.FindName("lblTodayQueueBetaStatus")
        if ($null -ne $status) {
            $status.Text = "TodayQueueBeta v3: Initial load failed."
        }
    }
}
