# TabTimeline.ps1 - Focus History Timeline tab: visual timeline across projects

$script:TimelineViewMode = "List"

# Script-level helper so event handlers can always access it (local function defs are not reliably
# captured in WPF Add_SelectionChanged closures)
function Get-TimelineDaysBack {
    param([System.Windows.Controls.ComboBox]$Combo)
    if ($null -eq $Combo) { return 30 }
    switch ($Combo.SelectedIndex) {
        0 { return 30 }
        1 { return 90 }
        2 { return 0 }
        default { return 30 }
    }
}

#
# ---- Activity Tracking Specifications ----
# This script (along with TabDashboard.ps1) visualizes project activity.
# 
# 1. Data Sources (Active Days):
#    An "Active Day" is any day that has at least one of the following files:
#    - Focus History: `_ai-context/context/focus_history/YYYY-MM-DD.md`
#    - Decision Log:  `_ai-context/context/decision_log/YYYY-MM-DD_topic.md`
#
# 2. Timeline Tab Display:
#    - Both sources are merged chronologically into a single timeline.
#    - Focus History shows a preview of the "## 今やってること" (Now doing) section.
#    - Decision Log shows the topic with a "[Decision]" prefix.
#    - Periods with no activity are indicated with a "-- N days gap --" block.
#    - Clicking any entry opens the corresponding markdown file in the Editor tab.
#    - The bottom status bar shows the total number of entries, the number of 
#      unique active days, the oldest/newest dates, and an "Active Rate" % for the period.
#
# 3. Dashboard Activity Bar Display (in TabDashboard.ps1):
#    - Shows a 30-day mini-timeline using small bars (dots).
#    - Green (#a6e3a1) = Activity exists on that day (either Focus or Decision)
#    - Dark Gray (#45475a) = No activity on that day
#    - Label Format: `Activity: X/30d (Y total, since MM/dd)`
#      - X: Number of unique active days in the last 30 days
#      - Y: Total number of combined snapshot/log files across the entire project history
#      - MM/dd: The date of the oldest recorded entry
#    - Label Color indicates recent activity level (last 30 days):
#      - >= 10 days:  Green (#a6e3a1)
#      - 3 - 9 days:  Sky Blue (#89dceb)
#      - 1 - 2 days:  Blue (#89b4fa)
#      - 0 days:      Gray (#6c7086)
# ------------------------------------------
function Get-FocusPreview {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return "" }

    try {
        $lines = Get-Content $FilePath -Encoding UTF8 -ErrorAction SilentlyContinue
        $inSection = $false
        foreach ($line in $lines) {
            if ($line -match '^## 今やってること' -or $line -match '^## Now doing') {
                $inSection = $true
                continue
            }
            if ($inSection -and $line -match '^##\s') {
                break  # next section
            }
            if ($inSection -and $line -match '^\s*-\s+\S') {
                $preview = ($line -replace '^\s*-\s+', '').Trim()
                if ($preview.Length -gt 80) { $preview = $preview.Substring(0, 77) + "..." }
                return $preview
            }
        }
        # Fallback: first non-empty, non-header, non-comment line
        foreach ($line in $lines) {
            $t = $line.Trim()
            if ($t -ne "" -and -not $t.StartsWith("#") -and -not $t.StartsWith("<!--") -and -not $t.StartsWith("---") -and -not ($t -match '^更新:') -and $t -ne "-") {
                if ($t.Length -gt 80) { $t = $t.Substring(0, 77) + "..." }
                return $t
            }
        }
    }
    catch { }
    return ""
}

function New-TimelineEntry {
    param(
        [datetime]$Date,
        [string]$Preview,
        [string]$FilePath,
        [string]$ProjectName,
        [System.Windows.Window]$Window
    )

    $border = New-Object System.Windows.Controls.Border
    $border.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#313244")
    )
    $border.BorderBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#45475a")
    )
    $border.BorderThickness = New-Object System.Windows.Thickness(1)
    $border.CornerRadius = New-Object System.Windows.CornerRadius(4)
    $border.Padding = New-Object System.Windows.Thickness(10, 6, 10, 6)
    $border.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
    $border.Cursor = [System.Windows.Input.Cursors]::Hand

    $grid = New-Object System.Windows.Controls.Grid
    $col0 = New-Object System.Windows.Controls.ColumnDefinition
    $col0.Width = [System.Windows.GridLength]::new(110)
    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($col0) | Out-Null
    $grid.ColumnDefinitions.Add($col1) | Out-Null

    $dayOfWeek = $Date.ToString("ddd")
    $dateBlock = New-Object System.Windows.Controls.TextBlock
    $dateBlock.Text = "$($Date.ToString('yyyy-MM-dd')) $dayOfWeek"
    $dateBlock.FontSize = 12
    $dateBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
    $dateBlock.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#89b4fa")
    )
    $dateBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.Grid]::SetColumn($dateBlock, 0)

    $previewBlock = New-Object System.Windows.Controls.TextBlock
    $previewBlock.Text = if ([string]::IsNullOrEmpty($Preview)) { "(no preview)" } else { $Preview }
    $previewBlock.FontSize = 12
    $fgColor = if ([string]::IsNullOrEmpty($Preview)) { "#6c7086" } else { "#cdd6f4" }
    $previewBlock.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($fgColor)
    )
    $previewBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $previewBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetColumn($previewBlock, 1)

    $grid.Children.Add($dateBlock) | Out-Null
    $grid.Children.Add($previewBlock) | Out-Null
    $border.Child = $grid

    # Hover effect
    $border.Add_MouseEnter({
            $this.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#45475a")
            )
        })
    $border.Add_MouseLeave({
            $this.Background = [System.Windows.Media.SolidColorBrush](
                [System.Windows.Media.ColorConverter]::ConvertFromString("#313244")
            )
        })

    # Click: open in Editor tab
    $border.Tag = @{ FilePath = $FilePath; ProjectName = $ProjectName; Window = $Window }
    $border.Add_MouseLeftButtonDown({
            param($s, $e)
            $data = $s.Tag
            $w = $data.Window
            $fp = $data.FilePath
            $pn = $data.ProjectName

            # 1. Switch to Editor tab
            $tabMain = $w.FindName("tabMain")
            $tabMain.SelectedIndex = $script:TAB_EDITOR

            # 2. Sync project combo in Editor tab (this triggers tree population)
            $editorProjectCombo = $w.FindName("editorProjectCombo")
            if ($null -ne $editorProjectCombo -and $null -ne $pn) {
                # Find matching item in combo
                foreach ($item in $editorProjectCombo.Items) {
                    if ($item.ToString() -eq $pn) {
                        $editorProjectCombo.SelectedItem = $item
                        break
                    }
                }
            }

            # 3. Open the specific file (after project switch logic runs)
            Open-FileInEditor -FilePath $fp -Window $w
            $e.Handled = $true
        })

    return $border
}

function New-GapEntry {
    param([int]$GapDays)

    $block = New-Object System.Windows.Controls.TextBlock
    $gapText = if ($GapDays -eq 1) { "-- 1 day gap --" } else { "-- $GapDays days gap --" }
    $block.Text = $gapText
    $block.FontSize = 11
    $block.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#585b70")
    )
    $block.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $block.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)

    return $block
}

function Update-TimelineView {
    param(
        [System.Windows.Window]$Window,
        [hashtable]$ProjectInfo,
        [int]$DaysBack = 30  # 0 = all
    )

    $entriesPanel = $Window.FindName("timelineEntries")
    $statText = $Window.FindName("timelineStatText")
    $entriesPanel.Children.Clear()

    if ($null -eq $ProjectInfo) {
        $statText.Text = ""
        return
    }

    $histDir = Join-Path $ProjectInfo.AiContextContentPath "focus_history"
    $logDir = Join-Path $ProjectInfo.AiContextContentPath "decision_log"
    
    $hasHistory = Test-Path $histDir
    $hasLogs = Test-Path $logDir

    if (-not $hasHistory -and -not $hasLogs) {
        $emptyBlock = New-Object System.Windows.Controls.TextBlock
        $emptyBlock.Text = "No focus_history/ or decision_log/ directory found for this project."
        $emptyBlock.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6c7086")
        )
        $emptyBlock.FontSize = 13
        $emptyBlock.Margin = New-Object System.Windows.Thickness(8)
        $entriesPanel.Children.Add($emptyBlock) | Out-Null
        $statText.Text = "Total: 0 entries"
        return
    }

    $cutoff = if ($DaysBack -gt 0) { (Get-Date).Date.AddDays(-$DaysBack) } else { [datetime]::MinValue }
    $filteredFiles = @()

    # Collect focus_history snapshots
    if ($hasHistory) {
        Get-ChildItem $histDir -Filter "*.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}$' } |
        ForEach-Object {
            $date = [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
            if ($date -ge $cutoff) {
                $filteredFiles += @{ Date = $date; Path = $_.FullName; Type = "Focus" }
            }
        }
    }

    # Collect decision_log entries
    if ($hasLogs) {
        Get-ChildItem $logDir -Filter "*.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "TEMPLATE.md" -and $_.BaseName -match '^(\d{4}-\d{2}-\d{2})_.*' } |
        ForEach-Object {
            $dateStr = $Matches[1]
            $date = [datetime]::ParseExact($dateStr, "yyyy-MM-dd", $null)
            if ($date -ge $cutoff) {
                # Extract topic for preview: YYYY-MM-DD_topic -> topic
                $topic = $_.BaseName.Substring(11)
                $filteredFiles += @{ Date = $date; Path = $_.FullName; Type = "Decision"; Topic = $topic }
            }
        }
    }

    if ($filteredFiles.Count -eq 0) {
        $emptyBlock = New-Object System.Windows.Controls.TextBlock
        $emptyBlock.Text = "No entries in the selected period."
        $emptyBlock.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6c7086")
        )
        $emptyBlock.FontSize = 13
        $emptyBlock.Margin = New-Object System.Windows.Thickness(8)
        $entriesPanel.Children.Add($emptyBlock) | Out-Null
        $statText.Text = "Total: 0 entries (in period)"
        return
    }

    # Sort descending (newest first)
    $filteredFiles = $filteredFiles | Sort-Object { $_.Date.ToString("yyyy-MM-dd") + "_" + $_.Type } -Descending

    # Build timeline entries (newest first, with gap indicators)
    $prevDate = $null
    foreach ($entry in $filteredFiles) {
        if ($null -ne $prevDate -and $prevDate -ne $entry.Date) {
            $gap = ($prevDate - $entry.Date).Days - 1
            if ($gap -gt 0) {
                $gapEntry = New-GapEntry -GapDays $gap
                $entriesPanel.Children.Add($gapEntry) | Out-Null
            }
        }

        if ($entry.Type -eq "Focus") {
            $preview = "[Focus] " + (Get-FocusPreview -FilePath $entry.Path)
        }
        else {
            $preview = "[Decision] $($entry.Topic)"
        }
        
        $timelineEntry = New-TimelineEntry -Date $entry.Date -Preview $preview -FilePath $entry.Path -ProjectName $ProjectInfo.Name -Window $Window
        $entriesPanel.Children.Add($timelineEntry) | Out-Null

        $prevDate = $entry.Date
    }

    # Stats
    $newest = $filteredFiles[0].Date.ToString("yyyy-MM-dd")
    $oldest = $filteredFiles[$filteredFiles.Count - 1].Date.ToString("yyyy-MM-dd")
    
    # Calculate unique active days
    $uniqueDays = 0
    $daySet = @{}
    foreach ($entry in $filteredFiles) {
        $ds = $entry.Date.ToString("yyyy-MM-dd")
        if (-not $daySet.ContainsKey($ds)) {
            $daySet[$ds] = $true
            $uniqueDays++
        }
    }
    
    $totalDays = if ($DaysBack -gt 0) { $DaysBack } else { ($filteredFiles[0].Date - $filteredFiles[$filteredFiles.Count - 1].Date).Days + 1 }
    $activeRate = if ($totalDays -gt 0) { [math]::Round(($uniqueDays / $totalDays) * 100, 0) } else { 0 }
    $statText.Text = "Total: $($filteredFiles.Count) entries ($uniqueDays active days)  |  Oldest: $oldest  |  Newest: $newest  |  Active rate: $activeRate%"
}

function Switch-TimelineView {
    param([string]$Mode, [System.Windows.Window]$Window)
    try {
        $script:TimelineViewMode = $Mode

        $entriesPanel    = $Window.FindName("timelineEntries")
        $heatmapPanel    = $Window.FindName("timelineHeatmapPanel")
        $projectLabel    = $Window.FindName("timelineProjectLabel")
        $projectCombo    = $Window.FindName("timelineProjectCombo")
        $btnList         = $Window.FindName("timelineViewList")
        $btnHeatmap      = $Window.FindName("timelineViewHeatmap")

        $c = Get-ThemeColors -ThemeName $script:AppState.Theme

        if ($Mode -eq "List") {
            if ($null -ne $entriesPanel)  { $entriesPanel.Visibility  = [System.Windows.Visibility]::Visible }
            if ($null -ne $heatmapPanel)  { $heatmapPanel.Visibility  = [System.Windows.Visibility]::Collapsed }
            if ($null -ne $projectLabel)  { $projectLabel.Visibility  = [System.Windows.Visibility]::Visible }
            if ($null -ne $projectCombo)  { $projectCombo.Visibility  = [System.Windows.Visibility]::Visible }
            if ($null -ne $btnList)       { $btnList.Background    = New-ColorBrush $c.Surface2 }
            if ($null -ne $btnHeatmap)    { $btnHeatmap.Background = New-ColorBrush $c.Surface0 }
            # timelineEntries already has content from the last List-mode render; just make it visible
        }
        else {
            if ($null -ne $entriesPanel)  { $entriesPanel.Visibility  = [System.Windows.Visibility]::Collapsed }
            if ($null -ne $heatmapPanel)  { $heatmapPanel.Visibility  = [System.Windows.Visibility]::Visible }
            if ($null -ne $projectLabel)  { $projectLabel.Visibility  = [System.Windows.Visibility]::Collapsed }
            if ($null -ne $projectCombo)  { $projectCombo.Visibility  = [System.Windows.Visibility]::Collapsed }
            if ($null -ne $btnList)       { $btnList.Background    = New-ColorBrush $c.Surface0 }
            if ($null -ne $btnHeatmap)    { $btnHeatmap.Background = New-ColorBrush $c.Surface2 }

            $pCombo = $Window.FindName("timelinePeriodCombo")
            $days = 30
            if ($null -ne $pCombo) {
                switch ($pCombo.SelectedIndex) {
                    0 { $days = 30 }
                    1 { $days = 90 }
                    2 { $days = 0 }
                    default { $days = 30 }
                }
            }
            Update-HeatmapView -Window $Window -DaysBack $days
        }
    }
    catch { }
}

function New-HeatmapHeader {
    param([datetime]$StartDate, [datetime]$EndDate)

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = [System.Windows.Controls.Orientation]::Horizontal

    # Spacer for project name column
    $spacer = New-Object System.Windows.Controls.Border
    $spacer.Width = 150
    $row.Children.Add($spacer) | Out-Null

    $current = $StartDate
    $first = $true
    while ($current -le $EndDate) {
        $cell = New-Object System.Windows.Controls.TextBlock
        $cell.Width = 10
        $cell.Height = 16
        $cell.Margin = New-Object System.Windows.Thickness(1)
        $cell.FontSize = 8
        $cell.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $cell.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $cell.Foreground = New-ColorBrush "#6c7086"

        if ($first -or $current.Day -eq 1) {
            $cell.Text = $current.ToString("MMM")
        }
        else {
            $cell.Text = ""
        }

        $row.Children.Add($cell) | Out-Null
        $first = $false
        $current = $current.AddDays(1)
    }

    return $row
}

function New-HeatmapRow {
    param(
        [hashtable]$ProjectInfo,
        [datetime]$StartDate,
        [datetime]$EndDate,
        [System.Windows.Window]$Window
    )

    $c = Get-ThemeColors -ThemeName $script:AppState.Theme

    # Build lookup sets for O(1) date checking
    $focusSet    = @{}
    $decisionSet = @{}
    if ($null -ne $ProjectInfo.FocusHistoryDates) {
        foreach ($d in $ProjectInfo.FocusHistoryDates) {
            $focusSet[$d.ToString("yyyy-MM-dd")] = $true
        }
    }
    if ($null -ne $ProjectInfo.DecisionLogDates) {
        foreach ($d in $ProjectInfo.DecisionLogDates) {
            $decisionSet[$d.ToString("yyyy-MM-dd")] = $true
        }
    }

    # Determine display name suffix for combo matching
    $suffix = ""
    if ($ProjectInfo.Tier -eq "mini" -and $ProjectInfo.Category -eq "domain") { $suffix = " [Domain][Mini]" }
    elseif ($ProjectInfo.Tier -eq "mini")                                       { $suffix = " [Mini]" }
    elseif ($ProjectInfo.Category -eq "domain")                                 { $suffix = " [Domain]" }
    $displayName = $ProjectInfo.Name + $suffix

    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $row.Margin = New-Object System.Windows.Thickness(0, 1, 0, 1)

    # Project name label (clickable)
    $nameBlock = New-Object System.Windows.Controls.TextBlock
    $nameBlock.Text = $ProjectInfo.Name
    $nameBlock.Width = 150
    $nameBlock.FontSize = 11
    $nameBlock.Foreground = New-ColorBrush $c.Subtext1
    $nameBlock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $nameBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $nameBlock.Cursor = [System.Windows.Input.Cursors]::Hand
    $nameBlock.ToolTip = $displayName

    $nameBlock.Tag = @{ DisplayName = $displayName; Window = $Window }
    $nameBlock.Add_MouseLeftButtonDown({
        param($s, $e)
        try {
            $data = $s.Tag
            $w = $data.Window
            Switch-TimelineView -Mode "List" -Window $w
            $combo = $w.FindName("timelineProjectCombo")
            if ($null -ne $combo) {
                foreach ($item in $combo.Items) {
                    if ($item.ToString() -eq $data.DisplayName) {
                        $combo.SelectedItem = $item
                        break
                    }
                }
            }
            $e.Handled = $true
        }
        catch { }
    }.GetNewClosure())

    $row.Children.Add($nameBlock) | Out-Null

    # Date cells
    $aiCtxContent = $ProjectInfo.AiContextContentPath
    $histDir = Join-Path $aiCtxContent "focus_history"
    $logDir  = Join-Path $aiCtxContent "decision_log"

    $current = $StartDate
    while ($current -le $EndDate) {
        $ds = $current.ToString("yyyy-MM-dd")
        $hasFocus    = $focusSet.ContainsKey($ds)
        $hasDecision = $decisionSet.ContainsKey($ds)

        $colorHex = if ($hasFocus -and $hasDecision) { $c.Teal }
                    elseif ($hasFocus)                { $c.Green }
                    elseif ($hasDecision)             { $c.Blue }
                    else                              { $c.Surface1 }

        $ttText = if ($hasFocus -and $hasDecision) { "$ds`nFocus + Decision" }
                  elseif ($hasFocus)               { "$ds`nFocus" }
                  elseif ($hasDecision)            { "$ds`nDecision" }
                  else                             { "$ds`nNo activity" }

        $rect = New-Object System.Windows.Shapes.Rectangle
        $rect.Width   = 10
        $rect.Height  = 16
        $rect.Margin  = New-Object System.Windows.Thickness(1)
        $rect.RadiusX = 2
        $rect.RadiusY = 2
        $rect.Fill    = New-ColorBrush $colorHex
        $rect.ToolTip = $ttText

        if ($hasFocus -or $hasDecision) {
            $rect.Cursor = [System.Windows.Input.Cursors]::Hand
            $capturedDate    = $ds
            $capturedHistDir = $histDir
            $capturedLogDir  = $logDir
            $capturedWindow  = $Window

            $rect.Tag = @{
                DateStr = $capturedDate
                HistDir = $capturedHistDir
                LogDir  = $capturedLogDir
                Window  = $capturedWindow
            }
            $rect.Add_MouseLeftButtonDown({
                param($s, $e)
                try {
                    $data = $s.Tag
                    $w    = $data.Window
                    $fp   = $null

                    # Try focus_history first
                    $focusFile = Join-Path $data.HistDir "$($data.DateStr).md"
                    if (Test-Path $focusFile) {
                        $fp = $focusFile
                    }
                    else {
                        # Fallback: first matching decision_log file
                        $decFiles = Get-ChildItem $data.LogDir -Filter "$($data.DateStr)_*.md" `
                                        -ErrorAction SilentlyContinue
                        if ($null -ne $decFiles -and $decFiles.Count -gt 0) {
                            $fp = ($decFiles | Select-Object -First 1).FullName
                        }
                    }

                    if ($null -ne $fp) {
                        $tabMain = $w.FindName("tabMain")
                        if ($null -ne $tabMain) { $tabMain.SelectedIndex = $script:TAB_EDITOR }
                        Open-FileInEditor -FilePath $fp -Window $w
                    }
                    $e.Handled = $true
                }
                catch { }
            }.GetNewClosure())
        }

        $row.Children.Add($rect) | Out-Null
        $current = $current.AddDays(1)
    }

    return $row
}

function Update-HeatmapView {
    param([System.Windows.Window]$Window, [int]$DaysBack = 30)
    try {
        $heatmapPanel = $Window.FindName("timelineHeatmapPanel")
        $statText     = $Window.FindName("timelineStatText")
        if ($null -eq $heatmapPanel) { return }

        $heatmapPanel.Children.Clear()

        # Get all projects (use cache if fresh)
        $allProjects = Get-ProjectInfoList

        # Filter out hidden projects
        $visibleProjects = @($allProjects | Where-Object { -not (Test-ProjectHidden -Info $_) })

        if ($visibleProjects.Count -eq 0) {
            if ($null -ne $statText) { $statText.Text = "No projects" }
            return
        }

        $today = (Get-Date).Date

        # Determine date range
        if ($DaysBack -gt 0) {
            $startDate = $today.AddDays(-$DaysBack)
        }
        else {
            # All: find earliest activity date across all projects
            $earliest = $today
            foreach ($proj in $visibleProjects) {
                if ($null -ne $proj.FocusHistoryDates -and $proj.FocusHistoryDates.Count -gt 0) {
                    $minD = ($proj.FocusHistoryDates | Measure-Object -Minimum).Minimum
                    if ($minD -lt $earliest) { $earliest = $minD }
                }
                if ($null -ne $proj.DecisionLogDates -and $proj.DecisionLogDates.Count -gt 0) {
                    $minD = ($proj.DecisionLogDates | Measure-Object -Minimum).Minimum
                    if ($minD -lt $earliest) { $earliest = $minD }
                }
            }
            $startDate = $earliest
        }
        $endDate = $today

        # Header row
        $header = New-HeatmapHeader -StartDate $startDate -EndDate $endDate
        $heatmapPanel.Children.Add($header) | Out-Null

        # Project rows
        $totalActiveDays = 0
        foreach ($proj in $visibleProjects) {
            $projRow = New-HeatmapRow -ProjectInfo $proj -StartDate $startDate -EndDate $endDate -Window $Window
            $heatmapPanel.Children.Add($projRow) | Out-Null

            # Count active days in range for stats
            $allDates = @()
            if ($null -ne $proj.FocusHistoryDates) { $allDates += $proj.FocusHistoryDates }
            if ($null -ne $proj.DecisionLogDates)  { $allDates += $proj.DecisionLogDates }
            $uniqueActive = @($allDates | Where-Object { $_ -ge $startDate -and $_ -le $endDate } |
                ForEach-Object { $_.ToString("yyyy-MM-dd") } | Sort-Object -Unique)
            $totalActiveDays += $uniqueActive.Count
        }

        # Stats
        $periodDays = ($endDate - $startDate).Days + 1
        if ($null -ne $statText) {
            $statText.Text = "$($visibleProjects.Count) projects  |  Period: $periodDays days  |  Active days (total): $totalActiveDays"
        }

        # Legend
        $legend = $Window.FindName("timelineStats")
        if ($null -ne $legend) {
            # Remove existing legend items (keep only statText)
            $toRemove = @()
            foreach ($child in $legend.Children) {
                if ($child -ne $statText) { $toRemove += $child }
            }
            foreach ($item in $toRemove) { $legend.Children.Remove($item) | Out-Null }

            $c = Get-ThemeColors -ThemeName $script:AppState.Theme

            $legendItems = @(
                @{ Color = $c.Green; Label = " Focus" },
                @{ Color = $c.Blue;  Label = " Decision" },
                @{ Color = $c.Teal;  Label = " Both" }
            )
            foreach ($li in $legendItems) {
                $sep = New-Object System.Windows.Controls.TextBlock
                $sep.Text = "   "
                $sep.FontSize = 11
                $legend.Children.Add($sep) | Out-Null

                $sq = New-Object System.Windows.Shapes.Rectangle
                $sq.Width   = 10
                $sq.Height  = 10
                $sq.RadiusX = 2
                $sq.RadiusY = 2
                $sq.Fill = New-ColorBrush $li.Color
                $sq.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $legend.Children.Add($sq) | Out-Null

                $lbl = New-Object System.Windows.Controls.TextBlock
                $lbl.Text = $li.Label
                $lbl.FontSize = 11
                $lbl.Foreground = New-ColorBrush "#6c7086"
                $lbl.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $legend.Children.Add($lbl) | Out-Null
            }
        }
    }
    catch { }
}

function Initialize-TabTimeline {
    param([System.Windows.Window]$Window)

    $projectCombo = $Window.FindName("timelineProjectCombo")
    $periodCombo = $Window.FindName("timelinePeriodCombo")

    # Populate project dropdown
    foreach ($p in (Get-ProjectNameList)) {
        $projectCombo.Items.Add($p) | Out-Null
    }

    # Project selection changed
    $projectCombo.Add_SelectionChanged({
            try {
                $combo = $Window.FindName("timelineProjectCombo")
                if ($null -eq $combo.SelectedItem) { return }
                $comboText = $combo.SelectedItem.ToString()
                if ([string]::IsNullOrWhiteSpace($comboText)) { return }

                $proj = Get-SelectedEditorProject -ComboText $comboText
                if ($null -eq $proj) { return }

                $pCombo = $Window.FindName("timelinePeriodCombo")
                $days = Get-TimelineDaysBack -Combo $pCombo
                Update-TimelineView -Window $Window -ProjectInfo $proj -DaysBack $days
            }
            catch { }
        })

    # Period selection changed
    $periodCombo.Add_SelectionChanged({
            try {
                $pCombo = $Window.FindName("timelinePeriodCombo")
                $days = Get-TimelineDaysBack -Combo $pCombo

                if ($script:TimelineViewMode -eq "Heatmap") {
                    Update-HeatmapView -Window $Window -DaysBack $days
                }
                else {
                    $combo = $Window.FindName("timelineProjectCombo")
                    if ($null -eq $combo.SelectedItem) { return }
                    $comboText = $combo.SelectedItem.ToString()
                    if ([string]::IsNullOrWhiteSpace($comboText)) { return }

                    $proj = Get-SelectedEditorProject -ComboText $comboText
                    if ($null -eq $proj) { return }

                    Update-TimelineView -Window $Window -ProjectInfo $proj -DaysBack $days
                }
            }
            catch { }
        })

    # View toggle buttons
    $btnViewList    = $Window.FindName("timelineViewList")
    $btnViewHeatmap = $Window.FindName("timelineViewHeatmap")

    if ($null -ne $btnViewList) {
        $btnViewList.Add_Click({
            try { Switch-TimelineView -Mode "List" -Window $Window }
            catch { }
        }.GetNewClosure())
    }
    if ($null -ne $btnViewHeatmap) {
        $btnViewHeatmap.Add_Click({
            try { Switch-TimelineView -Mode "Heatmap" -Window $Window }
            catch { }
        }.GetNewClosure())
    }

    # Refresh timeline when the Timeline tab becomes active
    $tabMain = $Window.FindName("tabMain")
    $tabMain.Add_SelectionChanged({
            param($sender, $e)
            # Only respond to the TabControl itself, not bubbling events from ComboBoxes
            if ($e.OriginalSource -ne $sender) { return }

            $tab = $sender
            if ($tab.SelectedIndex -eq 2) { # Timeline tab
                try {
                    $pCombo = $Window.FindName("timelinePeriodCombo")
                    $days = Get-TimelineDaysBack -Combo $pCombo

                    if ($script:TimelineViewMode -eq "Heatmap") {
                        Update-HeatmapView -Window $Window -DaysBack $days
                    }
                    else {
                        $combo = $Window.FindName("timelineProjectCombo")
                        if ($null -eq $combo.SelectedItem) { return }
                        $comboText = $combo.SelectedItem.ToString()
                        if ([string]::IsNullOrWhiteSpace($comboText)) { return }

                        $proj = Get-SelectedEditorProject -ComboText $comboText
                        if ($null -eq $proj) { return }

                        Update-TimelineView -Window $Window -ProjectInfo $proj -DaysBack $days
                    }
                }
                catch { }
            }
        })

    # Pattern #8: trigger initial load by selecting first project
    if ($projectCombo.Items.Count -gt 0) {
        $projectCombo.SelectedIndex = 0
    }
}
