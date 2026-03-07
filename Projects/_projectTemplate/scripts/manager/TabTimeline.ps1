# TabTimeline.ps1 - Focus History Timeline tab: visual timeline across projects
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
            $tabMain.SelectedIndex = 1

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

function Initialize-TabTimeline {
    param([System.Windows.Window]$Window)

    $projectCombo = $Window.FindName("timelineProjectCombo")
    $periodCombo = $Window.FindName("timelinePeriodCombo")

    # Populate project dropdown
    foreach ($p in (Get-ProjectNameList)) {
        $projectCombo.Items.Add($p) | Out-Null
    }

    # Helper: resolve period ComboBox selection to days-back value
    function Get-SelectedDaysBack {
        param([System.Windows.Controls.ComboBox]$Combo)
        $sel = $Combo.SelectedIndex
        switch ($sel) {
            0 { return 30 }
            1 { return 90 }
            2 { return 0 }   # all
            default { return 30 }
        }
    }

    # Project selection changed
    $projectCombo.Add_SelectionChanged({
            $combo = $Window.FindName("timelineProjectCombo")
            if ($null -eq $combo.SelectedItem) { return }
            $comboText = $combo.SelectedItem.ToString()
            if ([string]::IsNullOrWhiteSpace($comboText)) { return }

            $proj = Get-SelectedEditorProject -ComboText $comboText
            if ($null -eq $proj) { return }

            $pCombo = $Window.FindName("timelinePeriodCombo")
            $days = Get-SelectedDaysBack -Combo $pCombo
            Update-TimelineView -Window $Window -ProjectInfo $proj -DaysBack $days
        })

    # Period selection changed
    $periodCombo.Add_SelectionChanged({
            $combo = $Window.FindName("timelineProjectCombo")
            if ($null -eq $combo.SelectedItem) { return }
            $comboText = $combo.SelectedItem.ToString()
            if ([string]::IsNullOrWhiteSpace($comboText)) { return }

            $proj = Get-SelectedEditorProject -ComboText $comboText
            if ($null -eq $proj) { return }

            $pCombo = $Window.FindName("timelinePeriodCombo")
            $days = Get-SelectedDaysBack -Combo $pCombo
            Update-TimelineView -Window $Window -ProjectInfo $proj -DaysBack $days
        })

    # Refresh timeline when the Timeline tab becomes active
    $tabMain = $Window.FindName("tabMain")
    $tabMain.Add_SelectionChanged({
            param($sender, $e)
            # Only respond to the TabControl itself, not bubbling events from ComboBoxes
            if ($e.OriginalSource -ne $sender) { return }

            $tab = $sender
            if ($tab.SelectedIndex -eq 2) { # Timeline tab
                $combo = $Window.FindName("timelineProjectCombo")
                if ($null -eq $combo.SelectedItem) { return }
                $comboText = $combo.SelectedItem.ToString()
                if ([string]::IsNullOrWhiteSpace($comboText)) { return }

                $proj = Get-SelectedEditorProject -ComboText $comboText
                if ($null -eq $proj) { return }

                $pCombo = $Window.FindName("timelinePeriodCombo")
                $days = Get-SelectedDaysBack -Combo $pCombo
                Update-TimelineView -Window $Window -ProjectInfo $proj -DaysBack $days
            }
        })
}
