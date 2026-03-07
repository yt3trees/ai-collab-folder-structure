# TabDashboard.ps1 - Dashboard tab: project cards with freshness indicators

# ---- Color helpers ----

function Get-FreshnessColor {
    param(
        [object]$Days,       # int or $null
        [int]$WarnAt,        # days threshold for yellow
        [int]$AlertAt        # days threshold for red
    )
    if ($null -eq $Days) { return "#f38ba8" }  # red (missing)
    if ($Days -le $WarnAt) { return "#a6e3a1" }  # green
    if ($Days -le $AlertAt) { return "#f9e2af" }  # yellow
    return "#f38ba8"                              # red
}

function Get-JunctionColor {
    param([string]$Status)
    switch ($Status) {
        "OK" { return "#a6e3a1" }
        "Missing" { return "#f38ba8" }
        "Broken" { return "#fab387" }
        default { return "#6c7086" }
    }
}

function New-ColorBrush {
    param([string]$Hex)
    return [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
    )
}

function Open-TerminalAtPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "-d `"$Path`""
    }
    elseif (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        Start-Process pwsh.exe -ArgumentList "-NoExit -Command `"Set-Location '$Path'`""
    }
    else {
        Start-Process powershell.exe -ArgumentList "-NoExit -Command `"Set-Location '$Path'`""
    }
}

function Open-AgentAtPath {
    param([string]$Path, [string]$Agent)
    if (-not (Test-Path $Path)) { return }
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "-d `"$Path`" -- pwsh.exe -NoExit -Command `"$Agent`""
    }
    elseif (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        Start-Process pwsh.exe -ArgumentList "-NoExit -Command `"Set-Location '$Path'; $Agent`""
    }
    else {
        Start-Process powershell.exe -ArgumentList "-NoExit -Command `"Set-Location '$Path'; $Agent`""
    }
}

# ---- Build one project card ----

function New-ProjectCard {
    param(
        [hashtable]$Info,
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [bool]$IsHidden = $false
    )

    # Outer card border
    $card = New-Object System.Windows.Controls.Border
    $card.Width = 260
    $card.MinHeight = 160
    $card.Margin = New-Object System.Windows.Thickness(0, 0, 8, 8)
    $card.Background = New-ColorBrush "#313244"
    $card.BorderBrush = New-ColorBrush "#45475a"
    $card.BorderThickness = New-Object System.Windows.Thickness(1)
    $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $card.Padding = New-Object System.Windows.Thickness(12)
    $card.Cursor = [System.Windows.Input.Cursors]::Arrow
    if ($IsHidden) { $card.Opacity = 0.45 }

    $stack = New-Object System.Windows.Controls.StackPanel

    # Store project info in variables for the closures
    $localProjName = $Info.Name
    $localIsMini = ($Info.Tier -eq "mini")
    $localIsDomain = ($Info.Category -eq "domain")
    $localProjPath = $Info.Path

    # --- Title row ---
    $titleRow = New-Object System.Windows.Controls.StackPanel
    $titleRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $titleRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = $Info.Name
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleColor = if ($Info.Category -eq "domain") { "#94e2d5" } else { "#cba6f7" }
    $titleBlock.Foreground = New-ColorBrush $titleColor

    $tierBadge = New-Object System.Windows.Controls.TextBlock
    $badgeText = if ($Info.Category -eq "domain" -and $Info.Tier -eq "mini") { " [DM]" }
    elseif ($Info.Category -eq "domain") { " [D]" }
    elseif ($Info.Tier -eq "mini") { " [M]" }
    else { " [F]" }
    $tierBadge.Text = $badgeText
    $tierBadge.FontSize = 11
    $tierBadge.Foreground = New-ColorBrush "#a6adc8"
    $tierBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $titleRow.Children.Add($titleBlock) | Out-Null
    $titleRow.Children.Add($tierBadge)  | Out-Null

    if ($IsHidden) {
        $hiddenBadge = New-Object System.Windows.Controls.TextBlock
        $hiddenBadge.Text = " [H]"
        $hiddenBadge.FontSize = 11
        $hiddenBadge.Foreground = New-ColorBrush "#f38ba8"
        $hiddenBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $titleRow.Children.Add($hiddenBadge) | Out-Null
    }

    $stack.Children.Add($titleRow) | Out-Null

    # --- Focus freshness ---
    $focusText = if ($null -eq $Info.FocusAge) { "Focus: --" } elseif ($Info.FocusAge -eq 0) { "Focus: today" } else { "Focus: $($Info.FocusAge)d ago" }
    $focusBlock = New-Object System.Windows.Controls.TextBlock
    $focusBlock.Text = $focusText
    $focusBlock.FontSize = 12
    $focusBlock.Foreground = New-ColorBrush (Get-FreshnessColor -Days $Info.FocusAge -WarnAt 7 -AlertAt 14)
    $focusBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
    $stack.Children.Add($focusBlock) | Out-Null

    # --- Summary freshness ---
    $summText = if ($null -eq $Info.SummaryAge) { "Summary: --" } elseif ($Info.SummaryAge -eq 0) { "Summary: today" } else { "Summary: $($Info.SummaryAge)d ago" }
    $summBlock = New-Object System.Windows.Controls.TextBlock
    $summBlock.Text = $summText
    $summBlock.FontSize = 12
    $summBlock.Foreground = New-ColorBrush (Get-FreshnessColor -Days $Info.SummaryAge -WarnAt 14 -AlertAt 30)
    $summBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
    $stack.Children.Add($summBlock) | Out-Null

    # --- Junction status ---
    $junctionColor = if ($Info.JunctionShared -eq "OK" -and $Info.JunctionObsidian -eq "OK" -and $Info.JunctionContext -eq "OK") { "#a6e3a1" }
    elseif ($Info.JunctionShared -eq "Missing" -or $Info.JunctionObsidian -eq "Missing" -or $Info.JunctionContext -eq "Missing") { "#f38ba8" }
    else { "#fab387" }
    $junctionBlock = New-Object System.Windows.Controls.TextBlock
    $junctionBlock.Text = "Junctions: $($Info.JunctionShared) / $($Info.JunctionObsidian) / $($Info.JunctionContext)"
    $junctionBlock.FontSize = 11
    $junctionBlock.Foreground = New-ColorBrush $junctionColor
    $junctionBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
    $stack.Children.Add($junctionBlock) | Out-Null

    # --- Decision log count ---
    if ($Info.DecisionLogCount -gt 0) {
        $dlBlock = New-Object System.Windows.Controls.TextBlock
        $dlBlock.Text = "Decisions: $($Info.DecisionLogCount)"
        $dlBlock.FontSize = 11
        $dlBlock.Foreground = New-ColorBrush "#89b4fa"
        $dlBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
        $stack.Children.Add($dlBlock) | Out-Null
    }

    # --- Activity bar (30 days) ---
    $today = (Get-Date).Date
    $historyDates = @()
    if ($null -ne $Info.FocusHistoryDates) { $historyDates += $Info.FocusHistoryDates }
    if ($null -ne $Info.DecisionLogDates) { $historyDates += $Info.DecisionLogDates }
    
    $historySet = @{}
    $historyDates = $historyDates | Sort-Object
    $totalDates = 0
    $recent30 = 0

    if ($historyDates.Count -gt 0) {
        foreach ($d in $historyDates) {
            $dateStr = $d.Date.ToString("yyyy-MM-dd")
            if (-not $historySet.ContainsKey($dateStr)) {
                $historySet[$dateStr] = $true
                $totalDates++
                if (($today - $d.Date).TotalDays -lt 30) { $recent30++ }
            }
        }
    }

    $labelText = if ($totalDates -eq 0) { "Activity (30d): --" } else {
        $oldest = $historyDates[0].ToString("MM/dd")
        "Activity: ${recent30}/30d ($totalDates total, since $oldest)"
    }

    # Build activity group (Label + Bar) - Clickable to jump to Timeline
    $activityGroup = New-Object System.Windows.Controls.StackPanel
    $activityGroup.Background = New-ColorBrush "Transparent"
    $activityGroup.Cursor = [System.Windows.Input.Cursors]::Hand
    $activityGroup.ToolTip = "Click to view full timeline"
    
    # Pre-calculate the exact display name used in dropdowns
    $exactDisplayName = $localProjName
    if ($localIsDomain -and $localIsMini) { $exactDisplayName += " [Domain][Mini]" }
    elseif ($localIsDomain) { $exactDisplayName += " [Domain]" }
    elseif ($localIsMini) { $exactDisplayName += " [Mini]" }
    $activityGroup.Tag = $exactDisplayName

    $activityLabel = New-Object System.Windows.Controls.TextBlock
    $activityLabel.Text = $labelText
    $activityLabel.FontSize = 11
    $labelColor = if ($recent30 -ge 10) { "#a6e3a1" } elseif ($recent30 -ge 3) { "#89dceb" } elseif ($totalDates -gt 0) { "#89b4fa" } else { "#6c7086" }
    $activityLabel.Foreground = New-ColorBrush $labelColor
    $activityLabel.Margin = New-Object System.Windows.Thickness(0, 6, 0, 2)
    $activityGroup.Children.Add($activityLabel) | Out-Null

    $barPanel = New-Object System.Windows.Controls.StackPanel
    $barPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    for ($i = 29; $i -ge 0; $i--) {
        $day = $today.AddDays(-$i)
        $rect = New-Object System.Windows.Shapes.Rectangle
        $rect.Width = 7
        $rect.Height = 12
        $rect.Margin = New-Object System.Windows.Thickness(0.5)
        $rect.RadiusX = 1
        $rect.RadiusY = 1
        $color = if ($historySet.ContainsKey($day.ToString("yyyy-MM-dd"))) { "#a6e3a1" } else { "#45475a" }
        $rect.Fill = New-ColorBrush $color
        $rect.ToolTip = $day.ToString("MM/dd (ddd)")
        $barPanel.Children.Add($rect) | Out-Null
    }
    $activityGroup.Children.Add($barPanel) | Out-Null

    $activityGroup.Add_MouseLeftButtonUp({
            param($sender, $e)
            $targetName = $sender.Tag
            $tabMain = $Window.FindName("tabMain")
            $timelineCombo = $Window.FindName("timelineProjectCombo")

            for ($i = 0; $i -lt $timelineCombo.Items.Count; $i++) {
                if ($timelineCombo.Items[$i].ToString() -eq $targetName) {
                    if ($timelineCombo.SelectedIndex -eq $i) { $timelineCombo.SelectedIndex = -1 }
                    $timelineCombo.SelectedIndex = $i
                    break
                }
            }
            $tabMain.SelectedIndex = 2
            $e.Handled = $true
        })
    $stack.Children.Add($activityGroup) | Out-Null

    # --- Action buttons ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)

    # [Check] button
    $btnCheck = New-Object System.Windows.Controls.Button
    $btnCheck.Content = "Check"
    $btnCheck.FontSize = 11
    $btnCheck.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
    $btnCheck.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    $btnCheck.Background = New-ColorBrush "#45475a"
    $btnCheck.Foreground = New-ColorBrush "#cdd6f4"
    $btnCheck.BorderThickness = New-Object System.Windows.Thickness(0)
    $btnCheck.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnCheck.Tag = @{ ProjName = $localProjName; IsMini = $localIsMini; IsDomain = $localIsDomain }
    $btnCheck.Add_Click({
            param($sender, $e)
            $data = $sender.Tag
            $tabMain = $Window.FindName("tabMain")
            $tabMain.SelectedIndex = 5
            $checkCombo = $Window.FindName("checkProjectCombo")
            $suffix = if ($data.IsDomain -and $data.IsMini) { " [Domain][Mini]" } elseif ($data.IsDomain) { " [Domain]" } elseif ($data.IsMini) { " [Mini]" } else { "" }
            $checkCombo.Text = "$($data.ProjName)$suffix"
            $checkMiniBox = $Window.FindName("checkMini")
            $checkMiniBox.IsChecked = $data.IsMini
        })
    $btnCheck.Add_MouseRightButtonUp({ param($sender, $e) $e.Handled = $true })

    # [Edit] button
    $btnEdit = New-Object System.Windows.Controls.Button
    $btnEdit.Content = "Edit"
    $btnEdit.FontSize = 11
    $btnEdit.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
    $btnEdit.Margin = New-Object System.Windows.Thickness(0, 0, 0, 0)
    $btnEdit.Background = New-ColorBrush "#45475a"
    $btnEdit.Foreground = New-ColorBrush "#cdd6f4"
    $btnEdit.BorderThickness = New-Object System.Windows.Thickness(0)
    $btnEdit.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnEdit.Tag = $exactDisplayName
    $btnEdit.Add_Click({
            param($sender, $e)
            $target = $sender.Tag
            $tabMain = $Window.FindName("tabMain")
            $tabMain.SelectedIndex = 1
            $editorCombo = $Window.FindName("editorProjectCombo")
            for ($i = 0; $i -lt $editorCombo.Items.Count; $i++) {
                if ($editorCombo.Items[$i].ToString() -eq $target) {
                    if ($editorCombo.SelectedIndex -eq $i) { $editorCombo.SelectedIndex = -1 }
                    $editorCombo.SelectedIndex = $i
                    break
                }
            }
        })
    $btnEdit.Add_MouseRightButtonUp({ param($sender, $e) $e.Handled = $true })

    # [Term] button
    $btnTerm = New-Object System.Windows.Controls.Button
    $btnTerm.Content = "Term"
    $btnTerm.FontSize = 11
    $btnTerm.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
    $btnTerm.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
    $btnTerm.Background = New-ColorBrush "#45475a"
    $btnTerm.Foreground = New-ColorBrush "#cdd6f4"
    $btnTerm.BorderThickness = New-Object System.Windows.Thickness(0)
    $btnTerm.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnTerm.Tag = $localProjPath
    $btnTerm.Add_Click({ param($sender, $e) Open-TerminalAtPath -Path $sender.Tag })
    $btnTerm.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            $termPath = $sender.Tag
            $popup = New-Object System.Windows.Controls.Primitives.Popup
            $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
            $popup.StaysOpen = $false
            $popup.AllowsTransparency = $true
            $border = New-Object System.Windows.Controls.Border
            $border.Background = New-ColorBrush "#313244"; $border.BorderBrush = New-ColorBrush "#45475a"; $border.BorderThickness = New-Object System.Windows.Thickness(1); $border.Padding = New-Object System.Windows.Thickness(2)
            $menuStack = New-Object System.Windows.Controls.StackPanel
            foreach ($agentDef in @(@{ Label = "Claude"; Cmd = "claude" }, @{ Label = "Gemini"; Cmd = "gemini" }, @{ Label = "Codex"; Cmd = "codex" })) {
                $menuItem = New-Object System.Windows.Controls.TextBlock
                $menuItem.Text = $agentDef.Label; $menuItem.Foreground = New-ColorBrush "#cdd6f4"; $menuItem.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5); $menuItem.Cursor = [System.Windows.Input.Cursors]::Hand
                $menuItem.Tag = @{ Path = $termPath; Cmd = $agentDef.Cmd; Popup = $popup }
                $menuItem.Add_MouseEnter({ $this.Background = New-ColorBrush "#45475a" }); $menuItem.Add_MouseLeave({ $this.Background = New-ColorBrush "#313244" })
                $menuItem.Add_MouseLeftButtonDown({
                        param($s, $ev)
                        $ev.Handled = $true
                        $d = $s.Tag
                        $d.Popup.IsOpen = $false
                        Open-AgentAtPath -Path $d.Path -Agent $d.Cmd
                    })
                $menuStack.Children.Add($menuItem) | Out-Null
            }
            $border.Child = $menuStack; $popup.Child = $border; $popup.IsOpen = $true
        })

    # [Dir] button
    $btnDir = New-Object System.Windows.Controls.Button
    $btnDir.Content = "Dir"
    $btnDir.FontSize = 11
    $btnDir.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
    $btnDir.Margin = New-Object System.Windows.Thickness(6, 0, 0, 0)
    $btnDir.Background = New-ColorBrush "#45475a"
    $btnDir.Foreground = New-ColorBrush "#cdd6f4"
    $btnDir.BorderThickness = New-Object System.Windows.Thickness(0)
    $btnDir.Cursor = [System.Windows.Input.Cursors]::Hand
    $btnDir.Tag = $localProjPath
    $btnDir.Add_Click({ param($sender, $e) if (Test-Path $sender.Tag) { Start-Process explorer.exe -ArgumentList $sender.Tag } })
    $btnDir.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            if (Test-Path $sender.Tag) { Start-Process code -ArgumentList "`"$($sender.Tag)`"" }
        })

    $btnPanel.Children.Add($btnCheck) | Out-Null
    $btnPanel.Children.Add($btnEdit)  | Out-Null
    $btnPanel.Children.Add($btnDir)   | Out-Null
    $btnPanel.Children.Add($btnTerm)  | Out-Null
    $stack.Children.Add($btnPanel)    | Out-Null

    # Right-click: Hide / Unhide
    $card.Tag = @{ Info = $Info; IsHidden = $IsHidden; Window = $Window }
    $card.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            $data = $sender.Tag
            $popup = New-Object System.Windows.Controls.Primitives.Popup
            $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
            $popup.StaysOpen = $false
            $popup.AllowsTransparency = $true
            $border = New-Object System.Windows.Controls.Border
            $border.Background = New-ColorBrush "#313244"; $border.BorderBrush = New-ColorBrush "#45475a"; $border.BorderThickness = New-Object System.Windows.Thickness(1); $border.Padding = New-Object System.Windows.Thickness(2)
            $menuStack = New-Object System.Windows.Controls.StackPanel
            $actionLabel = if ($data.IsHidden) { "Unhide from Dashboard" } else { "Hide from Dashboard" }
            $menuItem = New-Object System.Windows.Controls.TextBlock
            $menuItem.Text = $actionLabel; $menuItem.Foreground = New-ColorBrush "#cdd6f4"; $menuItem.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5); $menuItem.Cursor = [System.Windows.Input.Cursors]::Hand
            $menuItem.Add_MouseEnter({ $this.Background = New-ColorBrush "#45475a" }); $menuItem.Add_MouseLeave({ $this.Background = New-ColorBrush "#313244" })
            $menuItem.Add_MouseLeftButtonDown({
                    param($s, $ev)
                    $popup.IsOpen = $false
                    Set-ProjectHidden -Info $data.Info -Hidden (-not $data.IsHidden)
                    Update-Dashboard -Window $data.Window -ShowHidden ([bool]($data.Window.FindName("chkShowHidden").IsChecked)) -Force
                })
            $menuStack.Children.Add($menuItem) | Out-Null
            $border.Child = $menuStack; $popup.Child = $border; $popup.IsOpen = $true
        })

    $card.Child = $stack
    return $card
}

function Update-Dashboard {
    param([System.Windows.Window]$Window, [string]$FilterText = "", [bool]$ShowHidden = $false, [switch]$Force)
    $cardsPanel = $Window.FindName("dashboardCards")
    $cardsPanel.Children.Clear()
    $projects = Get-ProjectInfoList -Force:$Force
    $filter = $FilterText.Trim().ToLower()
    foreach ($proj in $projects) {
        $isHidden = Test-ProjectHidden -Info $proj
        if ($isHidden -and -not $ShowHidden) { continue }
        if ($filter -ne "" -and $proj.Name.ToLower() -notlike "*$filter*") { continue }
        $cardsPanel.Children.Add((New-ProjectCard -Info $proj -Window $Window -IsHidden $isHidden)) | Out-Null
    }
}

function Initialize-TabDashboard {
    param([System.Windows.Window]$Window, [string]$ScriptDir)
    $btnDashRefresh = $Window.FindName("btnDashRefresh")
    $txtDashFilter = $Window.FindName("txtDashFilter")
    $chkShowHidden = $Window.FindName("chkShowHidden")
    Update-Dashboard -Window $Window -Force
    $btnDashRefresh.Add_Click({ Update-Dashboard -Window $Window -FilterText $txtDashFilter.Text -ShowHidden ([bool]$chkShowHidden.IsChecked) -Force })
    $txtDashFilter.Add_TextChanged({ Update-Dashboard -Window $Window -FilterText $txtDashFilter.Text -ShowHidden ([bool]$chkShowHidden.IsChecked) })
    $chkShowHidden.Add_Click({ Update-Dashboard -Window $Window -FilterText $txtDashFilter.Text -ShowHidden ([bool]$chkShowHidden.IsChecked) })
    $Window.FindName("tabMain").Add_SelectionChanged({
            param($s, $e)
            if ($e.OriginalSource -ne $s) { return }
            if ($s.SelectedIndex -eq 0) { Update-Dashboard -Window $Window -FilterText $txtDashFilter.Text -ShowHidden ([bool]$chkShowHidden.IsChecked) }
        })
}
