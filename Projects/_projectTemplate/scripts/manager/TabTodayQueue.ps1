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

    foreach ($line in $lines) {
        if ($line -match '^###\s*進行中') {
            $inProgress = $true
            continue
        }
        if ($line -match '^###\s*完了') {
            $inProgress = $false
            continue
        }
        if (-not $inProgress) { continue }

        # Top-level unchecked task only.
        if ($line -notmatch '^\s{0,2}-\s+\[\s\]\s+(.+)$') { continue }
        $body = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($body)) { continue }
        if ($body -match '^<!--\s*Memo area') { continue }

        $dueDate = $null
        if ($body -match '\(Due:\s*(\d{4}-\d{2}-\d{2})\)') {
            try { $dueDate = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd", $null) } catch { $dueDate = $null }
        }

        $title = $body -replace '\s+\[\[Asana\]\([^)]+\)\]\s*$', ''
        $title = $title -replace '\s+\(Due:\s*\d{4}-\d{2}-\d{2}\)\s*$', ''
        $title = $title -replace '^\[(担当|コラボ|他)\]\s*', ''
        if ([string]::IsNullOrWhiteSpace($title)) { $title = "(untitled task)" }

        $tasks.Add(@{
                ProjectDisplayName = $projectDisplay
                Title              = $title
                DueDate            = $dueDate
                StartFile          = $sourceFile
            }) | Out-Null
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
    $row.ColumnDefinitions.Add($c0) | Out-Null
    $row.ColumnDefinitions.Add($c1) | Out-Null

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = "[$($Task.ProjectDisplayName)] $($Task.Title)  |  $($Task.DueText)"
    $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.Grid]::SetColumn($label, 0)
    $row.Children.Add($label) | Out-Null

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "Start"
    $btn.Style = $Window.TryFindResource("SmallButton")
    $btn.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
    $btn.Tag = @{
        Window      = $Window
        ProjectName = $Task.ProjectDisplayName
        StartFile   = $Task.StartFile
    }
    $btn.Add_Click({
            param($sender, $e)
            $d = $sender.Tag
            Select-TodayQueueProjectInEditor -Window $d.Window -ProjectDisplayName $d.ProjectName
            if (-not [string]::IsNullOrWhiteSpace([string]$d.StartFile) -and (Test-Path $d.StartFile)) {
                Open-FileInEditor -FilePath $d.StartFile -Window $d.Window
            }
        })

    [System.Windows.Controls.Grid]::SetColumn($btn, 1)
    $row.Children.Add($btn) | Out-Null

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