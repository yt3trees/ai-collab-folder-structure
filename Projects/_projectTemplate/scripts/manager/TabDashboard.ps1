# TabDashboard.ps1 - Dashboard tab: project cards with freshness indicators

# ---- Color helpers ----

function Get-FreshnessColor {
    param(
        [object]$Days,       # int or $null
        [int]$WarnAt,        # days threshold for yellow
        [int]$AlertAt,       # days threshold for red
        [hashtable]$ThemeColors
    )
    if ($null -eq $Days) { return $ThemeColors.Red }  # red (missing)
    if ($Days -le $WarnAt) { return $ThemeColors.Green }  # green
    if ($Days -le $AlertAt) { return $ThemeColors.Yellow }  # yellow
    return $ThemeColors.Red                              # red
}

function New-ColorBrush {
    param([string]$Hex)
    if ([string]::IsNullOrWhiteSpace($Hex)) { $Hex = "#FF00FF" } # Fallback
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

function Invoke-ResumeWork {
    param([string]$ProjPath, [string]$FeatureName)
    $safeFeature = $FeatureName.Trim() -replace '[\\/:*?"<>|]', '_'
    $now = Get-Date
    $yearStr = $now.ToString("yyyy")
    $monthStr = $now.ToString("yyyyMM")
    $dayStr = $now.ToString("yyyyMMdd")
    $workDir = Join-Path $ProjPath "shared\_work\$yearStr\$monthStr\${dayStr}_${safeFeature}"
    if (-not (Test-Path $workDir)) {
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    }
    Start-Process explorer.exe -ArgumentList $workDir
    Open-TerminalAtPath -Path $workDir
}

function Show-DirMenu {
    param(
        [string]$ProjPath,
        [object]$PlacementTarget  # Can be $null if PlacementMode is Mouse
    )
    
    $tc = Get-ThemeColors -ThemeName $script:AppState.Theme
    $popup = New-Object System.Windows.Controls.Primitives.Popup
    if ($null -ne $PlacementTarget) {
        $popup.PlacementTarget = $PlacementTarget
        $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    }
    else {
        $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
    }
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $border = New-Object System.Windows.Controls.Border
    $border.Background = New-ColorBrush $tc.Surface0
    $border.BorderBrush = New-ColorBrush $tc.Surface1
    $border.BorderThickness = New-Object System.Windows.Thickness(1)
    $border.Padding = New-Object System.Windows.Thickness(2)
    
    $menuStack = New-Object System.Windows.Controls.StackPanel
    
    $actions = @(
        @{ Label = "Open in VS Code"; Type = "code" },
        @{ Label = "Open _work Root"; Type = "root" }
    )
    
    foreach ($act in $actions) {
        $menuItem = New-Object System.Windows.Controls.TextBlock
        $menuItem.Text = $act.Label; $menuItem.Foreground = New-ColorBrush $tc.Text; $menuItem.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5); $menuItem.Cursor = [System.Windows.Input.Cursors]::Hand
        $menuItem.Tag = @{ Path = $ProjPath; Type = $act.Type; Popup = $popup; Colors = $tc }
        $menuItem.Add_MouseEnter({ $this.Background = New-ColorBrush $this.Tag.Colors.Surface1 })
        $menuItem.Add_MouseLeave({ $this.Background = New-ColorBrush $this.Tag.Colors.Surface0 })
        $menuItem.Add_MouseLeftButtonDown({
                param($s, $ev)
                $ev.Handled = $true
                $d = $s.Tag
                $d.Popup.IsOpen = $false
            
                if (-not (Test-Path $d.Path)) { return }
            
                if ($d.Type -eq "code") {
                    Start-Process code -ArgumentList "`"$($d.Path)`""
                }
                elseif ($d.Type -eq "root") {
                    $workRoot = Join-Path $d.Path "shared\_work"
                    if (Test-Path $workRoot) {
                        Start-Process explorer.exe -ArgumentList $workRoot
                    }
                    else {
                        [System.Windows.MessageBox]::Show("shared\_work folder does not exist.", "Folder Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                    }
                }
            })
        $menuStack.Children.Add($menuItem) | Out-Null
    }
    
    $border.Child = $menuStack
    $popup.Child = $border
    $popup.IsOpen = $true
    
    return $popup
}

# ---- Build one project card ----

function New-ProjectCard {
    param(
        [hashtable]$Info,
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [bool]$IsHidden = $false
    )

    $c = Get-ThemeColors -ThemeName $script:AppState.Theme

    # Outer card border
    $card = New-Object System.Windows.Controls.Border
    $card.Width = 260
    $card.MinHeight = 150
    $card.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
    $card.Background = New-ColorBrush $c.Surface0
    $card.BorderBrush = New-ColorBrush $c.Surface1
    $card.BorderThickness = New-Object System.Windows.Thickness(1)
    $card.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $card.Padding = New-Object System.Windows.Thickness(10)
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
    $titleColor = if ($Info.Category -eq "domain") { $c.Teal } else { $c.Mauve }
    $titleBlock.Foreground = New-ColorBrush $titleColor

    $tierBadge = New-Object System.Windows.Controls.TextBlock
    $badgeText = if ($Info.Category -eq "domain" -and $Info.Tier -eq "mini") { " [DM]" }
    elseif ($Info.Category -eq "domain") { " [D]" }
    elseif ($Info.Tier -eq "mini") { " [M]" }
    else { " [F]" }
    $tierBadge.Text = $badgeText
    $tierBadge.FontSize = 11
    $tierBadge.Foreground = New-ColorBrush $c.Subtext1
    $tierBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $titleRow.Children.Add($titleBlock) | Out-Null
    $titleRow.Children.Add($tierBadge)  | Out-Null

    if ($IsHidden) {
        $hiddenBadge = New-Object System.Windows.Controls.TextBlock
        $hiddenBadge.Text = " [H]"
        $hiddenBadge.FontSize = 11
        $hiddenBadge.Foreground = New-ColorBrush $c.Red
        $hiddenBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $titleRow.Children.Add($hiddenBadge) | Out-Null
    }

    # --- Junction health badge (only when broken) ---
    $brokenJunctions = @()
    if ($Info.JunctionShared  -ne "OK") { $brokenJunctions += "shared" }
    if ($Info.JunctionObsidian -ne "OK") { $brokenJunctions += "obsidian" }
    if ($Info.JunctionContext  -ne "OK") { $brokenJunctions += "context" }
    if ($brokenJunctions.Count -gt 0) {
        $junctionBadge = New-Object System.Windows.Controls.TextBlock
        $junctionBadge.Text = " [!!] Junction: $($brokenJunctions -join ', ')"
        $junctionBadge.FontSize = 11
        $junctionBadge.Foreground = New-ColorBrush $c.Red
        $junctionBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $junctionBadge.ToolTip = "Broken junctions: $($brokenJunctions -join ', ')"
        $titleRow.Children.Add($junctionBadge) | Out-Null
    }

    $stack.Children.Add($titleRow) | Out-Null

    # --- Focus freshness & size ---
    $focusAge = $Info.FocusAge
    $focusText = if ($null -eq $focusAge) { "Focus: --" } elseif ($focusAge -eq 0) { "Focus: today" } else { "Focus: $($focusAge)d ago" }

    if ($null -ne $Info.FocusTokens) {
        $focusText += " ($($Info.FocusTokens)tk, $($Info.FocusLines)L)"
    }

    $focusBlock = New-Object System.Windows.Controls.TextBlock
    $focusBlock.Text = $focusText
    $focusBlock.FontSize = 12
    $focusBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)

    $focusWarn = $false; $focusCrit = $false
    if ($null -ne $Info.FocusTokens) {
        if ($Info.FocusTokens -ge 1200) { $focusCrit = $true }
        elseif ($Info.FocusTokens -ge 800) { $focusWarn = $true }
    }

    if ($focusCrit) {
        $focusBlock.Foreground = New-ColorBrush $c.Red
        $focusBlock.Text += " (Metabo!)"
    }
    elseif ($focusWarn) {
        $focusBlock.Foreground = New-ColorBrush $c.Peach
    }
    else {
        $focusBlock.Foreground = New-ColorBrush (Get-FreshnessColor -Days $focusAge -WarnAt 7 -AlertAt 14 -ThemeColors $c)
    }
    $stack.Children.Add($focusBlock) | Out-Null

    # --- Summary freshness & size ---
    $summAge = $Info.SummaryAge
    $summText = if ($null -eq $summAge) { "Summary: --" } elseif ($summAge -eq 0) { "Summary: today" } else { "Summary: $($summAge)d ago" }

    if ($null -ne $Info.SummaryTokens) {
        $summText += " ($($Info.SummaryTokens)tk, $($Info.SummaryLines)L)"
    }

    $summBlock = New-Object System.Windows.Controls.TextBlock
    $summBlock.Text = $summText
    $summBlock.FontSize = 12
    $summBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)

    $summWarn = $false; $summCrit = $false
    if ($null -ne $Info.SummaryTokens) {
        if ($Info.SummaryTokens -ge 1200) { $summCrit = $true }
        elseif ($Info.SummaryTokens -ge 800) { $summWarn = $true }
    }

    if ($summCrit) {
        $summBlock.Foreground = New-ColorBrush $c.Red
        $summBlock.Text += " (Metabo!)"
    }
    elseif ($summWarn) {
        $summBlock.Foreground = New-ColorBrush $c.Peach
    }
    else {
        $summBlock.Foreground = New-ColorBrush (Get-FreshnessColor -Days $summAge -WarnAt 14 -AlertAt 30 -ThemeColors $c)
    }
    $stack.Children.Add($summBlock) | Out-Null

    # --- Decision log count ---
    if ($Info.DecisionLogCount -gt 0) {
        $dlBlock = New-Object System.Windows.Controls.TextBlock
        $dlBlock.Text = "Decisions: $($Info.DecisionLogCount)"
        $dlBlock.FontSize = 11
        $dlBlock.Foreground = New-ColorBrush $c.Blue
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
    $labelColor = if ($recent30 -ge 10) { $c.Green } elseif ($recent30 -ge 3) { $c.Sky } elseif ($totalDates -gt 0) { $c.Blue } else { $c.Overlay0 }
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
        $color = if ($historySet.ContainsKey($day.ToString("yyyy-MM-dd"))) { $c.Green } else { $c.Surface1 }
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
            $tabMain.SelectedIndex = $script:TAB_TIMELINE
            $e.Handled = $true
        })
    $stack.Children.Add($activityGroup) | Out-Null

    # --- Action buttons ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnPanel.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)

    # Helper for card buttons to ensure theme consistency
    $createCardButton = {
        param($label, $margin)
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $label
        $btn.Margin = $margin
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $cardStyle = $Window.TryFindResource("CardButton")
        if ($null -ne $cardStyle) {
            $btn.Style = $cardStyle
        }
        else {
            $btn.FontSize = 11
            $btn.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
            $btn.Background = New-ColorBrush $c.Surface1
            $btn.Foreground = New-ColorBrush $c.Text
            $btn.BorderThickness = New-Object System.Windows.Thickness(0)
        }
        return $btn
    }

    # [Edit] button
    $btnEdit = &$createCardButton "Edit" (New-Object System.Windows.Thickness(0, 0, 0, 0))
    $btnEdit.Tag = $exactDisplayName
    $btnEdit.Add_Click({
            param($sender, $e)
            $target = $sender.Tag
            $tabMain = $Window.FindName("tabMain")
            $tabMain.SelectedIndex = $script:TAB_EDITOR
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
    $btnTerm = &$createCardButton "Term" (New-Object System.Windows.Thickness(0, 0, 6, 0))
    $btnTerm.Tag = $localProjPath
    $btnTerm.Add_Click({ param($sender, $e) Open-TerminalAtPath -Path $sender.Tag })
    $btnTerm.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            $termPath = $sender.Tag
            $tc = Get-ThemeColors -ThemeName $script:AppState.Theme
            $popup = New-Object System.Windows.Controls.Primitives.Popup
            $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
            $popup.StaysOpen = $false
            $popup.AllowsTransparency = $true
            $border = New-Object System.Windows.Controls.Border
            $border.Background = New-ColorBrush $tc.Surface0; $border.BorderBrush = New-ColorBrush $tc.Surface1; $border.BorderThickness = New-Object System.Windows.Thickness(1); $border.Padding = New-Object System.Windows.Thickness(2)
            $menuStack = New-Object System.Windows.Controls.StackPanel
            foreach ($agentDef in @(@{ Label = "Claude"; Cmd = "claude" }, @{ Label = "Gemini"; Cmd = "gemini" }, @{ Label = "Codex"; Cmd = "codex" })) {
                $menuItem = New-Object System.Windows.Controls.TextBlock
                $menuItem.Text = $agentDef.Label; $menuItem.Foreground = New-ColorBrush $tc.Text; $menuItem.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5); $menuItem.Cursor = [System.Windows.Input.Cursors]::Hand
                $menuItem.Tag = @{ Path = $termPath; Cmd = $agentDef.Cmd; Popup = $popup; Colors = $tc }
                $menuItem.Add_MouseEnter({ $this.Background = New-ColorBrush $this.Tag.Colors.Surface1 })
                $menuItem.Add_MouseLeave({ $this.Background = New-ColorBrush $this.Tag.Colors.Surface0 })
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
    $btnDir = &$createCardButton "Dir" (New-Object System.Windows.Thickness(0, 0, 6, 0))
    $btnDir.Tag = $localProjPath
    $btnDir.Add_Click({ param($sender, $e) if (Test-Path $sender.Tag) { Start-Process explorer.exe -ArgumentList $sender.Tag } })
    $btnDir.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            if ($null -ne $script:currentDirPopup) {
                $script:currentDirPopup.IsOpen = $false
            }
            $script:currentDirPopup = Show-DirMenu -ProjPath $sender.Tag -PlacementTarget $null
        })

    $btnPanel.Children.Add($btnDir)   | Out-Null
    $btnPanel.Children.Add($btnTerm)  | Out-Null
    $btnPanel.Children.Add($btnEdit)  | Out-Null
    $stack.Children.Add($btnPanel)    | Out-Null

    # Right-click: Hide / Unhide
    $card.Tag = @{ Info = $Info; IsHidden = $IsHidden; Window = $Window; ScriptDir = $ScriptDir }
    $card.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            $data = $sender.Tag
            $tc = Get-ThemeColors -ThemeName $script:AppState.Theme
            $popup = New-Object System.Windows.Controls.Primitives.Popup
            $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
            $popup.StaysOpen = $false
            $popup.AllowsTransparency = $true
            $border = New-Object System.Windows.Controls.Border
            $border.Background = New-ColorBrush $tc.Surface0; $border.BorderBrush = New-ColorBrush $tc.Surface1; $border.BorderThickness = New-Object System.Windows.Thickness(1); $border.Padding = New-Object System.Windows.Thickness(2)
            $menuStack = New-Object System.Windows.Controls.StackPanel
            $actionLabel = if ($data.IsHidden) { "Unhide from Dashboard" } else { "Hide from Dashboard" }
            $menuItem = New-Object System.Windows.Controls.TextBlock
            $menuItem.Text = $actionLabel; $menuItem.Foreground = New-ColorBrush $tc.Text; $menuItem.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5); $menuItem.Cursor = [System.Windows.Input.Cursors]::Hand
            $menuItem.Background = New-ColorBrush "Transparent"  # Ensure clickability
            $menuItem.Tag = @{ CardData = $data; Popup = $popup; Colors = $tc }
            $menuItem.Add_MouseEnter({ $this.Background = New-ColorBrush $this.Tag.Colors.Surface1 }); $menuItem.Add_MouseLeave({ $this.Background = New-ColorBrush "Transparent" })
            $menuItem.Add_MouseLeftButtonDown({
                    param($s, $ev)
                    $ev.Handled = $true
                    $d = $s.Tag.CardData
                    $s.Tag.Popup.IsOpen = $false
                    Set-ProjectHidden -Info $d.Info -Hidden (-not $d.IsHidden)
                    Update-Dashboard -Window $d.Window -ShowHidden ([bool]($d.Window.FindName("chkShowHidden").IsChecked)) -Force -ScriptDir $d.ScriptDir
                })
            $menuStack.Children.Add($menuItem) | Out-Null
            $sep = New-Object System.Windows.Controls.Border
            $sep.Height = 1; $sep.Background = New-ColorBrush $tc.Surface1; $sep.Margin = New-Object System.Windows.Thickness(4, 2, 4, 2)
            $menuStack.Children.Add($sep) | Out-Null
            $resumeLabel = New-Object System.Windows.Controls.TextBlock
            $resumeLabel.Text = "Resume Work"; $resumeLabel.Foreground = New-ColorBrush $tc.Subtext1; $resumeLabel.FontSize = 10
            $resumeLabel.Padding = New-Object System.Windows.Thickness(12, 4, 12, 2)
            $menuStack.Children.Add($resumeLabel) | Out-Null
            $resumeRow = New-Object System.Windows.Controls.StackPanel
            $resumeRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $resumeRow.Margin = New-Object System.Windows.Thickness(8, 0, 8, 8)
            $resumeBox = New-Object System.Windows.Controls.TextBox
            $resumeBox.Width = 130; $resumeBox.FontSize = 12
            $resumeBox.Background = New-ColorBrush $tc.Surface1; $resumeBox.Foreground = New-ColorBrush $tc.Text
            $resumeBox.BorderBrush = New-ColorBrush $tc.Overlay0; $resumeBox.BorderThickness = New-Object System.Windows.Thickness(1)
            $resumeBox.Padding = New-Object System.Windows.Thickness(6, 3, 6, 3); $resumeBox.CaretBrush = New-ColorBrush $tc.Text
            $resumeBtn = New-Object System.Windows.Controls.Button
            $resumeBtn.Content = ">"; $resumeBtn.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0)
            $resumeBtn.FontSize = 12; $resumeBtn.Padding = New-Object System.Windows.Thickness(10, 3, 10, 3)
            $resumeBtn.Background = New-ColorBrush $tc.Blue; $resumeBtn.Foreground = New-ColorBrush $tc.Base
            $resumeBtn.BorderThickness = New-Object System.Windows.Thickness(0); $resumeBtn.Cursor = [System.Windows.Input.Cursors]::Hand
            $resumeBox.Tag = @{ ProjPath = $data.Info.Path; Popup = $popup }
            $resumeBox.Add_KeyDown({
                    param($s, $ev)
                    if ($ev.Key -eq [System.Windows.Input.Key]::Return) {
                        $ev.Handled = $true
                        $d = $s.Tag; $feature = $s.Text.Trim(); $d.Popup.IsOpen = $false
                        if (-not [string]::IsNullOrWhiteSpace($feature)) { Invoke-ResumeWork -ProjPath $d.ProjPath -FeatureName $feature }
                    }
                })
            $resumeBtn.Tag = @{ ProjPath = $data.Info.Path; Popup = $popup; Box = $resumeBox }
            $resumeBtn.Add_Click({
                    param($s, $ev)
                    $d = $s.Tag; $feature = $d.Box.Text.Trim(); $d.Popup.IsOpen = $false
                    if (-not [string]::IsNullOrWhiteSpace($feature)) { Invoke-ResumeWork -ProjPath $d.ProjPath -FeatureName $feature }
                })
            $resumeRow.Children.Add($resumeBox) | Out-Null; $resumeRow.Children.Add($resumeBtn) | Out-Null
            $menuStack.Children.Add($resumeRow) | Out-Null
            $border.Child = $menuStack; $popup.Child = $border; $popup.IsOpen = $true
            $resumeBox.Focus() | Out-Null
        })

    $card.Child = $stack
    return $card
}

$script:DashLastFilter     = $null
$script:DashLastShowHidden = $null
$script:DashLastBuildTime  = [datetime]::MinValue
$script:DashRefreshRunning = $false
$script:DashAutoRefreshTimer = $null
$script:DashRefreshPollTimers = @{}

function Set-AppStateProjectsSafe {
    param([object[]]$Projects)
    if ($script:AppState -is [hashtable]) {
        $script:AppState["Projects"] = $Projects
    }
    else {
        $script:AppState.Projects = $Projects
    }
}

function Stop-DashboardAutoRefreshTimer {
    if ($null -ne $script:DashAutoRefreshTimer) {
        $script:DashAutoRefreshTimer.Stop()
        $script:DashAutoRefreshTimer = $null
    }
}

function Start-DashboardAutoRefreshTimer {
    param([System.Windows.Window]$Window)
    Stop-DashboardAutoRefreshTimer
    $minutes = [int]$script:AppState.DashboardAutoRefreshMinutes
    if ($minutes -le 0) { return }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMinutes($minutes)
    $timer.Tag = $Window
    $timer.Add_Tick({
        param($sender, $e)
        $win = $sender.Tag
        $scriptDir = $script:AppState.ScriptDir
        $filter = ""
        $showHidden = $false
        try {
            $f = $win.FindName("txtDashFilter")
            if ($null -ne $f) { $filter = $f.Text }
            $h = $win.FindName("chkShowHidden")
            if ($null -ne $h) { $showHidden = [bool]$h.IsChecked }
        } catch {}
        Start-DashboardAsyncRefresh -Window $win -FilterText $filter -ShowHidden $showHidden `
            -ScriptDir $scriptDir -IncludeTokens $false
    }.GetNewClosure())
    $timer.Start()
    $script:DashAutoRefreshTimer = $timer
}

# ---- Today Queue Snooze ----

$script:TodayQueueSnooze = @{}
$script:DashboardTodayQueueViewMode = "Action"
$script:DashboardTodayQueueListMaxItems = 300

function Get-SnoozeFilePath {
    return Join-Path (Join-Path $script:AppState.WorkspaceRoot "_config") "today_queue_snooze.json"
}

function Load-TodayQueueSnooze {
    try {
        $path = Get-SnoozeFilePath
        if (-not (Test-Path $path)) { return }
        $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:TodayQueueSnooze = @{}
        $now = Get-Date
        foreach ($prop in $raw.PSObject.Properties) {
            $dt = [datetime]::Parse($prop.Value)
            if ($dt -gt $now) { $script:TodayQueueSnooze[$prop.Name] = $dt }
        }
    }
    catch {}
}

function Save-TodayQueueSnooze {
    try {
        $obj = @{}
        $now = Get-Date
        foreach ($kv in $script:TodayQueueSnooze.GetEnumerator()) {
            if ($kv.Value -gt $now) { $obj[$kv.Key] = $kv.Value.ToString("o") }
        }
        ConvertTo-Json -InputObject $obj | Set-Content (Get-SnoozeFilePath) -Encoding UTF8
    }
    catch {}
}

function Add-TodayQueueSnooze {
    param([string]$Key)
    if ($null -eq $script:TodayQueueSnooze) { $script:TodayQueueSnooze = @{} }
    $script:TodayQueueSnooze[$Key] = (Get-Date).Date.AddDays(1)
    Save-TodayQueueSnooze
}

function Clear-TodayQueueSnooze {
    $script:TodayQueueSnooze = @{}
}

function Test-TodayQueueSnoozed {
    param([string]$Key)
    if ($null -eq $script:TodayQueueSnooze) { return $false }
    if ($script:TodayQueueSnooze.ContainsKey($Key)) {
        if ($script:TodayQueueSnooze[$Key] -gt (Get-Date)) { return $true }
        $script:TodayQueueSnooze.Remove($Key)
    }
    return $false
}

function Get-TodayQueueSnoozeKey {
    param([hashtable]$Task)
    $gid = [string]$Task.AsanaTaskGid
    if (-not [string]::IsNullOrWhiteSpace($gid)) { return $gid }
    return ([string]$Task.ProjectDisplayName) + "|" + ([string]$Task.Title)
}

function Update-DashboardStats {
    param(
        [System.Windows.Window]$Window,
        [object[]]$Projects,
        [string]$FilterText,
        [bool]$ShowHidden
    )
    if ($null -eq $Window) { return }
    $lbl = $Window.FindName("lblDashStats")
    $statusProject = $Window.FindName("statusProject")
    if ($null -eq $lbl) { return }

    $totalAll = 0
    $totalVisible = 0
    $activeToday = 0
    $focusStale = 0
    $focusStaleThreshold = 7
    if ($null -ne $Projects) {
        $f = if ($null -eq $FilterText) { "" } else { [string]$FilterText }
        $f = $f.Trim().ToLowerInvariant()
        foreach ($p in $Projects) {
            $totalAll++
            $isHidden = Test-ProjectHidden -Info $p
            if ($isHidden -and -not $ShowHidden) { continue }
            if ($f -ne "" -and ([string]$p.Name).ToLowerInvariant() -notlike "*$f*") { continue }
            $totalVisible++
            if ($p.FocusAge -eq 0) { $activeToday++ }
            if ($null -eq $p.FocusAge -or [int]$p.FocusAge -gt $focusStaleThreshold) { $focusStale++ }
        }
    }

    $overdueCount = [int]$script:DashOverdueCount
    $parts = @()
    if ($totalVisible -eq $totalAll) { $parts += "$totalVisible projects" }
    else { $parts += "$totalVisible / $totalAll projects" }
    if ($activeToday -gt 0) { $parts += "$activeToday active today" }
    if ($overdueCount -gt 0) { $parts += "$overdueCount overdue tasks" }
    if ($focusStale -gt 0) { $parts += "$focusStale Focus stale (${focusStaleThreshold}d+)" }
    $lbl.Text = ($parts -join "  |  ")

    $onDashboard = $false
    try {
        $tabMain = $Window.FindName("tabMain")
        if ($null -ne $tabMain) { $onDashboard = ($tabMain.SelectedIndex -eq 0) }
    }
    catch {}

    if ($onDashboard) {
        $lbl.Visibility = [System.Windows.Visibility]::Visible
        if ($null -ne $statusProject) { $statusProject.Visibility = [System.Windows.Visibility]::Collapsed }
    }
    else {
        $lbl.Visibility = [System.Windows.Visibility]::Collapsed
        if ($null -ne $statusProject) { $statusProject.Visibility = [System.Windows.Visibility]::Visible }
    }
}

# Render cards from a pre-fetched project list (no I/O)
function Invoke-RenderDashboardCards {
    param(
        [System.Windows.Controls.Panel]$CardsPanel,
        [object[]]$Projects,
        [System.Windows.Window]$Window,
        [string]$FilterText,
        [bool]$ShowHidden,
        [string]$ScriptDir
    )
    $CardsPanel.Children.Clear()
    $filter = $FilterText.Trim().ToLower()
    foreach ($proj in $Projects) {
        $isHidden = Test-ProjectHidden -Info $proj
        if ($isHidden -and -not $ShowHidden) { continue }
        if ($filter -ne "" -and $proj.Name.ToLower() -notlike "*$filter*") { continue }
        $CardsPanel.Children.Add((New-ProjectCard -Info $proj -Window $Window -IsHidden $isHidden -ScriptDir $ScriptDir)) | Out-Null
    }
    Update-DashboardStats -Window $Window -Projects $Projects -FilterText $FilterText -ShowHidden $ShowHidden
}

# Run project discovery in a background Runspace; update cache and re-render when done.
# Returns immediately so the UI thread is never blocked.
#
# IncludeTokens=$false : full project scan via ProjectDiscovery.ps1, returns Hashtable list
# IncludeTokens=$true  : token-only scan via python, returns JSON string "{path:count,...}"
#                        then merges into existing cache on the UI thread (avoids Deserialized
#                        Hashtable problems when passing complex objects across runspace boundary)
function Start-DashboardAsyncRefresh {
    param(
        [System.Windows.Window]$Window,
        [string]$FilterText,
        [bool]$ShowHidden,
        [string]$ScriptDir,
        [bool]$IncludeTokens = $false
    )
    if ($script:DashRefreshRunning) { return }
    $script:DashRefreshRunning = $true

    $btnRef = $Window.FindName("btnDashRefresh")
    if ($null -ne $btnRef) {
        $btnRef.IsEnabled = $false
        $btnRef.Content = "Loading..."
    }

    $workspaceRoot   = $script:AppState.WorkspaceRoot
    $pathsConfig     = $script:AppState.PathsConfig
    $discoveryPath   = Join-Path (Join-Path $ScriptDir "manager") "ProjectDiscovery.ps1"
    $tokenScriptPath = Join-Path $ScriptDir "get_tokens.py"

    $timerKey = [guid]::NewGuid().ToString("N")

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('_WorkspaceRoot',   $workspaceRoot)
    $rs.SessionStateProxy.SetVariable('_PathsConfig',     $pathsConfig)
    $rs.SessionStateProxy.SetVariable('_DiscoveryPath',   $discoveryPath)
    $rs.SessionStateProxy.SetVariable('_TokenScriptPath', $tokenScriptPath)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs

    if ($IncludeTokens) {
        # Collect file paths from current cache on the UI thread (safe), pass to runspace
        $filePaths = @()
        if ($null -ne $script:ProjectInfoCache) {
            foreach ($p in $script:ProjectInfoCache) {
                if ($null -ne $p.FocusFile)   { $filePaths += $p.FocusFile }
                if ($null -ne $p.SummaryFile) { $filePaths += $p.SummaryFile }
            }
        }
        $rs.SessionStateProxy.SetVariable('_FilePaths', $filePaths)
        # Runspace returns a JSON string - no complex object crossing the boundary
        [void]$ps.AddScript({
            if ($null -eq $_FilePaths -or $_FilePaths.Count -eq 0) { return '{}' }
            $argsToPass = @('--files') + @($_FilePaths)
            $out = & python $_TokenScriptPath @argsToPass 2>$null
            if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($out))) { return $out }
            return '{}'
        })
    } else {
        [void]$ps.AddScript({
            $script:AppState = @{ WorkspaceRoot = $_WorkspaceRoot; PathsConfig = $_PathsConfig; Projects = @() }
            . $_DiscoveryPath
            return (Get-ProjectInfoList -Force)
        })
    }
    $asyncHandle = $ps.BeginInvoke()

    $pollTimer = New-Object System.Windows.Threading.DispatcherTimer
    $pollTimer.Interval = [timespan]::FromMilliseconds(150)
    $pollTimer.Tag = @{
        PS = $ps; RS = $rs; Handle = $asyncHandle
        Window = $Window; FilterText = $FilterText; ShowHidden = $ShowHidden; ScriptDir = $ScriptDir
        BtnRefresh = $btnRef; IncludeTokens = $IncludeTokens
        Cache = $script:ProjectInfoCache
        TimerKey = $timerKey
    }
    $pollTimer.Add_Tick({
        param($sender, $e)
        $d = $sender.Tag
        if (-not $d.Handle.IsCompleted) { return }
        $sender.Stop()
        $panel = $d.Window.FindName("dashboardCards")
        try {
            if ($d.IncludeTokens) {
                # Token-only path: parse JSON and merge into cache passed via Tag
                $tokenJson = ($d.PS.EndInvoke($d.Handle) | Select-Object -First 1)
                if (-not [string]::IsNullOrWhiteSpace($tokenJson) -and $tokenJson -ne '{}') {
                    $tokenDataRaw = $tokenJson | ConvertFrom-Json
                    $tokenData = @{}
                    foreach ($prop in $tokenDataRaw.PSObject.Properties) {
                        $tokenData[$prop.Name.ToLowerInvariant()] = [int]$prop.Value
                    }
                    if ($null -ne $d.Cache) {
                        foreach ($p in $d.Cache) {
                            if ($null -ne $p.FocusFile) {
                                $key = $p.FocusFile.ToLowerInvariant()
                                if ($tokenData.ContainsKey($key)) { $p['FocusTokens'] = $tokenData[$key] }
                            }
                            if ($null -ne $p.SummaryFile) {
                                $key = $p.SummaryFile.ToLowerInvariant()
                                if ($tokenData.ContainsKey($key)) { $p['SummaryTokens'] = $tokenData[$key] }
                            }
                        }
                    }
                }
                if ($null -ne $panel -and $null -ne $d.Cache) {
                    $curFilter     = $d.Window.FindName("txtDashFilter").Text
                    $curShowHidden = [bool]($d.Window.FindName("chkShowHidden").IsChecked)
                    Invoke-RenderDashboardCards -CardsPanel $panel -Projects $d.Cache `
                        -Window $d.Window -FilterText $curFilter -ShowHidden $curShowHidden `
                        -ScriptDir $d.ScriptDir
                }
            } else {
                # Full scan path: results are plain Hashtables from this runspace (SkipTokens)
                $results = @($d.PS.EndInvoke($d.Handle))
                if ($null -ne $results -and $results.Count -gt 0) {
                    $g0 = @($results | Where-Object { $_.Name -eq '_INHOUSE' })
                    $g1 = @($results | Where-Object { $_.Category -eq 'domain' -and $_.Tier -eq 'full' } | Sort-Object { $_.Name })
                    $g2 = @($results | Where-Object { $_.Category -eq 'domain' -and $_.Tier -eq 'mini' } | Sort-Object { $_.Name })
                    $g3 = @($results | Where-Object { $_.Name -ne '_INHOUSE' -and $_.Category -ne 'domain' } | Sort-Object { $_.Name })
                    $sorted = $g0 + $g1 + $g2 + $g3
                    $script:ProjectInfoCache     = $sorted
                    $script:ProjectInfoCacheTime = Get-Date
                    Set-AppStateProjectsSafe -Projects $sorted
                    if ($null -ne $panel) {
                        $curFilter     = $d.Window.FindName("txtDashFilter").Text
                        $curShowHidden = [bool]($d.Window.FindName("chkShowHidden").IsChecked)
                        Invoke-RenderDashboardCards -CardsPanel $panel -Projects $sorted `
                            -Window $d.Window -FilterText $curFilter -ShowHidden $curShowHidden `
                            -ScriptDir $d.ScriptDir
                        $script:DashLastFilter     = $curFilter
                        $script:DashLastShowHidden = $curShowHidden
                        $script:DashLastBuildTime  = $script:ProjectInfoCacheTime
                    }
                }
            }
        }
        catch {
            # On error: leave existing panel content as-is
        }
        finally {
            if ($script:DashRefreshPollTimers.ContainsKey($d.TimerKey)) {
                $script:DashRefreshPollTimers.Remove($d.TimerKey)
            }
            try { $d.PS.Dispose() } catch {}
            try { $d.RS.Close() } catch {}
            try { $d.RS.Dispose() } catch {}
            $script:DashRefreshRunning = $false
            if ($null -ne $d.BtnRefresh) {
                $d.BtnRefresh.IsEnabled = $true
                $d.BtnRefresh.Content = "Refresh"
            }
        }
    }.GetNewClosure())
    $script:DashRefreshPollTimers[$timerKey] = $pollTimer
    $pollTimer.Start()
}

function Update-Dashboard {
    param([System.Windows.Window]$Window, [string]$FilterText = "", [bool]$ShowHidden = $false, [switch]$Force, [string]$ScriptDir = "")
    $cardsPanel = $Window.FindName("dashboardCards")
    if ($null -eq $cardsPanel) { return }

    # Skip rebuild entirely if cache is still fresh and nothing changed
    if (-not $Force) {
        $cacheIsFresh = ($null -ne $script:ProjectInfoCache) -and
            (((Get-Date) - $script:ProjectInfoCacheTime).TotalSeconds -lt $script:ProjectInfoCacheTTL)
        $alreadyBuilt = ($script:DashLastBuildTime -ne [datetime]::MinValue) -and
            ($script:DashLastBuildTime -ge $script:ProjectInfoCacheTime)
        $nothingChanged = ($FilterText -eq $script:DashLastFilter) -and
            ($ShowHidden -eq $script:DashLastShowHidden) -and $alreadyBuilt
        if ($cacheIsFresh -and $nothingChanged -and $cardsPanel.Children.Count -gt 0) { return }
    }

    # Stale cache exists: show stale cards immediately then async-refresh (avoids UI freeze)
    # Do NOT reset DashRefreshRunning here - let the guard in Start-DashboardAsyncRefresh
    # skip silently if a refresh is already in progress (prevents concurrent Runspace launch).
    if (-not $Force -and $null -ne $script:ProjectInfoCache) {
        Invoke-RenderDashboardCards -CardsPanel $cardsPanel -Projects $script:ProjectInfoCache `
            -Window $Window -FilterText $FilterText -ShowHidden $ShowHidden -ScriptDir $ScriptDir
        # Update tracked state immediately after rendering so rapid toggle does not hit
        # nothingChanged early-return (DashLastShowHidden was only set in async callbacks before)
        $script:DashLastFilter     = $FilterText
        $script:DashLastShowHidden = $ShowHidden
        Start-DashboardAsyncRefresh -Window $Window -FilterText $FilterText -ShowHidden $ShowHidden `
            -ScriptDir $ScriptDir -IncludeTokens $false
        return
    }

    # Force (Refresh button): show stale cards immediately, then async refresh to avoid UI freeze
    if ($Force) {
        try {
            $projects = @(Get-ProjectInfoList -Force)
            if ($projects.Count -gt 0) {
                $script:ProjectInfoCache     = $projects
                $script:ProjectInfoCacheTime = Get-Date
                Set-AppStateProjectsSafe -Projects $projects
            }
            $script:DashLastFilter     = $FilterText
            $script:DashLastShowHidden = $ShowHidden
            $script:DashLastBuildTime  = $script:ProjectInfoCacheTime
            Invoke-RenderDashboardCards -CardsPanel $cardsPanel -Projects $projects -Window $Window `
                -FilterText $FilterText -ShowHidden $ShowHidden -ScriptDir $ScriptDir
        }
        catch {
            [System.Windows.MessageBox]::Show(
                "Dashboard refresh failed:`n$($_.Exception.Message)",
                "Refresh Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
        }
        return
    }

    # No cache, no Force: synchronous fast scan (filesystem only, no Python) - same as original
    $cardsPanel.Children.Clear()
    $projects = Get-ProjectInfoList -SkipTokens
    $script:DashLastFilter     = $FilterText
    $script:DashLastShowHidden = $ShowHidden
    $script:DashLastBuildTime  = $script:ProjectInfoCacheTime
    Invoke-RenderDashboardCards -CardsPanel $cardsPanel -Projects $projects -Window $Window `
        -FilterText $FilterText -ShowHidden $ShowHidden -ScriptDir $ScriptDir
}

function Show-ConfirmDoneDialog {
    param(
        [string]$ProjectName,
        [string]$TaskTitle,
        [System.Windows.Window]$Owner
    )

    $c = Get-ThemeColors -ThemeName $script:AppState.Theme

    $dlg = New-Object System.Windows.Window
    $dlg.WindowStyle = [System.Windows.WindowStyle]::None
    $dlg.AllowsTransparency = $true
    $dlg.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $dlg.Width = 420
    $dlg.SizeToContent = [System.Windows.SizeToContent]::Height
    $dlg.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dlg.ShowInTaskbar = $false
    if ($null -ne $Owner) { $dlg.Owner = $Owner }

    $outer = New-Object System.Windows.Controls.Border
    $outer.Background = New-ColorBrush $c.Surface0
    $outer.BorderBrush = New-ColorBrush $c.Surface2
    $outer.BorderThickness = New-Object System.Windows.Thickness(1)
    $outer.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $outer.Padding = New-Object System.Windows.Thickness(20, 16, 20, 12)

    $stack = New-Object System.Windows.Controls.StackPanel

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = "Mark as Done in Asana?"
    $header.Foreground = New-ColorBrush $c.Text
    $header.FontSize = 13
    $header.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")
    $header.FontWeight = [System.Windows.FontWeights]::SemiBold
    $header.Margin = New-Object System.Windows.Thickness(0, 0, 0, 6)
    $stack.Children.Add($header) | Out-Null

    $projNameClean = $ProjectName -replace '\s*\[(?:Domain|Mini)\]', ''
    $info = New-Object System.Windows.Controls.TextBlock
    $info.Text = "[$($projNameClean.Trim())]  $TaskTitle"
    $info.Foreground = New-ColorBrush $c.Subtext1
    $info.FontSize = 11
    $info.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas, Segoe UI")
    $info.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $info.Margin = New-Object System.Windows.Thickness(0, 0, 0, 16)
    $stack.Children.Add($info) | Out-Null

    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right

    $smallBtnStyle = if ($null -ne $Owner) { $Owner.TryFindResource("SmallButton") } else { $null }

    $cancelBtn = New-Object System.Windows.Controls.Button
    $cancelBtn.Content = "Cancel"
    $cancelBtn.Width = 80
    $cancelBtn.Height = 28
    $cancelBtn.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    if ($null -ne $smallBtnStyle) { $cancelBtn.Style = $smallBtnStyle }
    $cancelBtn.Background = New-ColorBrush $c.Surface1
    $cancelBtn.Foreground = New-ColorBrush $c.Subtext1
    $cancelBtn.Add_Click({ $dlg.DialogResult = $false }.GetNewClosure())

    $confirmBtn = New-Object System.Windows.Controls.Button
    $confirmBtn.Content = "Done"
    $confirmBtn.Width = 80
    $confirmBtn.Height = 28
    if ($null -ne $smallBtnStyle) { $confirmBtn.Style = $smallBtnStyle }
    $confirmBtn.Background = New-ColorBrush $c.Green
    $confirmBtn.Foreground = New-ColorBrush $c.Base
    $confirmBtn.FontWeight = [System.Windows.FontWeights]::SemiBold
    $confirmBtn.Add_Click({ $dlg.DialogResult = $true }.GetNewClosure())

    $btnPanel.Children.Add($cancelBtn) | Out-Null
    $btnPanel.Children.Add($confirmBtn) | Out-Null
    $stack.Children.Add($btnPanel) | Out-Null

    $outer.Child = $stack
    $dlg.Content = $outer

    $dlg.Add_PreviewKeyDown({
        param($s, $ev)
        if ($ev.Key -eq [System.Windows.Input.Key]::Return) {
            $ev.Handled = $true
            $s.DialogResult = $true
        }
        elseif ($ev.Key -eq [System.Windows.Input.Key]::Escape) {
            $ev.Handled = $true
            $s.DialogResult = $false
        }
    })
    $dlg.Add_MouseLeftButtonDown({ $this.DragMove() })

    $ok = $dlg.ShowDialog()
    return ($ok -eq $true)
}

function Start-DashboardRefreshAfterAsanaSync {
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
            try { Update-DashboardTodayQueueWidget -Window $targetWindow } catch {}
        }
    }).GetNewClosure())

    $timer.Start()
}

function Update-UnsnoozeButton {
    param([System.Windows.Window]$Window, [int]$Count)
    $btn = $Window.FindName("btnDashUnsnooze")
    if ($null -eq $btn) { return }
    if ($Count -gt 0) {
        $btn.Content = ([string][char]0x21A9) + " $Count snoozed"
        $btn.Visibility = [System.Windows.Visibility]::Visible
    }
    else {
        $btn.Visibility = [System.Windows.Visibility]::Collapsed
    }
}

function Update-DashboardTodayQueueModeButton {
    param([System.Windows.Window]$Window)

    $btn = $Window.FindName("btnDashTodayQueueViewMode")
    if ($null -eq $btn) { return }

    $isList = ([string]$script:DashboardTodayQueueViewMode -eq "List")
    $btn.Content = if ($isList) { "$([char]0x2630)" } else { "$([char]0x25EB)" }
    $btn.ToolTip = if ($isList) { "List view (switch to Action)" } else { "Action view (switch to List)" }
}

function Toggle-DashboardTodayQueueViewMode {
    param([System.Windows.Window]$Window)

    if ([string]$script:DashboardTodayQueueViewMode -eq "List") {
        $script:DashboardTodayQueueViewMode = "Action"
    }
    else {
        $script:DashboardTodayQueueViewMode = "List"
    }

    Update-DashboardTodayQueueModeButton -Window $Window
    Update-DashboardTodayQueueWidget -Window $Window
}

function New-DashboardQueueSectionHeader {
    param([string]$Label)
    $tc = Get-ThemeColors -ThemeName $script:AppState.Theme
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness(0, 4, 0, 4)
    $col0 = New-Object System.Windows.Controls.ColumnDefinition
    $col0.Width = [System.Windows.GridLength]::Auto
    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($col0) | Out-Null
    $grid.ColumnDefinitions.Add($col1) | Out-Null
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $Label
    $lbl.FontSize = 10
    $lbl.Foreground = New-ColorBrush $tc.Overlay0
    $lbl.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $lbl.Margin = New-Object System.Windows.Thickness(2, 0, 6, 0)
    [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
    $grid.Children.Add($lbl) | Out-Null
    $line = New-Object System.Windows.Shapes.Rectangle
    $line.Height = 1
    $line.Fill = New-ColorBrush $tc.Surface1
    $line.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [System.Windows.Controls.Grid]::SetColumn($line, 1)
    $grid.Children.Add($line) | Out-Null
    return $grid
}

function New-DashboardQueueShowMoreItem {
    param(
        [System.Windows.Window]$Window,
        [array]$Tasks,
        [int]$LastBucketGroup,
        [int]$TotalVisible,
        [int]$SnoozeCount
    )
    $tc = Get-ThemeColors -ThemeName $script:AppState.Theme
    $btn = New-Object System.Windows.Controls.Button
    $smallStyle = $Window.TryFindResource("SmallButton")
    if ($null -ne $smallStyle) { $btn.Style = $smallStyle }
    $btn.Content = "+$($Tasks.Count) more..."
    $btn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
    $btn.VerticalAlignment = [System.Windows.VerticalAlignment]::Stretch
    $btn.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
    $btn.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    $btn.MinHeight = 32
    $btn.Margin = New-Object System.Windows.Thickness(-4, -2, -4, -2)
    $btn.Background = [System.Windows.Media.Brushes]::Transparent
    $btn.BorderThickness = New-Object System.Windows.Thickness(0)
    $btn.Padding = New-Object System.Windows.Thickness(0)
    $btn.Foreground = New-ColorBrush $tc.Subtext0
    $btn.FontSize = 11
    $btn.Cursor = [System.Windows.Input.Cursors]::Hand
    $btn.Focusable = $false
    $btn.FocusVisualStyle = $null
    $btn.Tag = @{ Window = $Window; Tasks = $Tasks; LastBucketGroup = $LastBucketGroup; TotalVisible = $TotalVisible; SnoozeCount = $SnoozeCount }
    $btn.Add_Click({
        param($sender, $e)
        try {
            $d = $sender.Tag
            $lst = $d.Window.FindName("lstDashTodayQueue")
            if ($null -eq $lst) { return }
            $lst.Items.RemoveAt($lst.Items.Count - 1)
            $lastBucket = [int]$d.LastBucketGroup
            foreach ($t in $d.Tasks) {
                $bucket = [int]$t.SortBucket
                $bg = if ($bucket -le 1) { $bucket } elseif ($bucket -le 3) { 2 } elseif ($bucket -eq 4) { 3 } else { 4 }
                if ($bg -ne $lastBucket) {
                    $label = switch ($bg) {
                        0 { "Overdue" }
                        1 { "Today" }
                        2 { "This Week" }
                        3 { "Later" }
                        default { "No Due" }
                    }
                    [void]$lst.Items.Add((New-DashboardQueueSectionHeader -Label $label))
                    $lastBucket = $bg
                }
                [void]$lst.Items.Add((New-DashboardTodayQueueListItem -Task $t -Window $d.Window))
            }
            $lbl = $d.Window.FindName("lblDashTodayQueueStatus")
            if ($null -ne $lbl) {
                $msg = "Dashboard Queue: $($d.TotalVisible) tasks (showing $($d.TotalVisible))"
                if ($d.SnoozeCount -gt 0) { $msg += ", $($d.SnoozeCount) snoozed" }
                $lbl.Text = $msg
            }
        } catch {
            [System.Windows.MessageBox]::Show($_.Exception.Message, "Error") | Out-Null
        }
    })
    return $btn
}

function New-DashboardTodayQueueCompactListItem {
    param([hashtable]$Task)

    $projectNameForDisplay = ([string]$Task.ProjectDisplayName) -replace '\s*\[(?:Domain|Mini)\]', ''
    $projectNameForDisplay = $projectNameForDisplay.Trim()
    $taskTitleForDisplay = ([string]$Task.Title) -replace '^\[[^\]]+\]\s*', ''
    $taskTitleForDisplay = $taskTitleForDisplay.Trim()

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = "[$projectNameForDisplay] $taskTitleForDisplay | $($Task.DueText)"
    $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $label.Margin = New-Object System.Windows.Thickness(2, 1, 2, 1)
    return $label
}

function New-DashboardTodayQueueListItem {
    param(
        [hashtable]$Task,
        [System.Windows.Window]$Window
    )

    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
    $row.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
    $row.MinHeight = 32

    $themeName = if ([string]::IsNullOrWhiteSpace([string]$script:AppState.Theme)) { "Default" } else { [string]$script:AppState.Theme }
    $tc = Get-ThemeColors -ThemeName $themeName

    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c0.Width = [System.Windows.GridLength]::new(220)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::new(96)
    $c3 = New-Object System.Windows.Controls.ColumnDefinition
    $c3.Width = [System.Windows.GridLength]::Auto
    $c4 = New-Object System.Windows.Controls.ColumnDefinition
    $c4.Width = [System.Windows.GridLength]::Auto
    $c5 = New-Object System.Windows.Controls.ColumnDefinition
    $c5.Width = [System.Windows.GridLength]::Auto
    $row.ColumnDefinitions.Add($c0) | Out-Null
    $row.ColumnDefinitions.Add($c1) | Out-Null
    $row.ColumnDefinitions.Add($c2) | Out-Null
    $row.ColumnDefinitions.Add($c3) | Out-Null
    $row.ColumnDefinitions.Add($c4) | Out-Null
    $row.ColumnDefinitions.Add($c5) | Out-Null

    $projectNameForDisplay = ([string]$Task.ProjectDisplayName) -replace '\s*\[(?:Domain|Mini)\]', ''
    $projectNameForDisplay = $projectNameForDisplay.Trim()

    $project = New-Object System.Windows.Controls.TextBlock
    $project.Text = $projectNameForDisplay
    $project.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $project.Foreground = New-ColorBrush $tc.Subtext0
    $project.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $project.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
    $project.LineHeight = 18
    $project.Margin = New-Object System.Windows.Thickness(5, 0, 0, 0)
    [System.Windows.Controls.Grid]::SetColumn($project, 0)
    $row.Children.Add($project) | Out-Null

    $taskTitleForDisplay = ([string]$Task.Title) -replace '^\[[^\]]+\]\s*', ''
    $taskTitleForDisplay = $taskTitleForDisplay.Trim()

    $title = New-Object System.Windows.Controls.TextBlock
    $title.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $title.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $title.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
    $title.LineHeight = 18
    $title.Margin = New-Object System.Windows.Thickness(0, 0, 0, 0)

    $isSubtask = ($Task.ContainsKey('IsSubtask') -and [bool]$Task.IsSubtask)
    $parentTitle = if ($Task.ContainsKey('ParentTitle')) { [string]$Task.ParentTitle } else { '' }
    if ($isSubtask -and -not [string]::IsNullOrWhiteSpace($parentTitle)) {
        $parentDisplay = ($parentTitle -replace '^\[[^\]]+\]\s*', '').Trim()
        $runMain = New-Object System.Windows.Documents.Run($taskTitleForDisplay)
        $title.Inlines.Add($runMain) | Out-Null
        $runParent = New-Object System.Windows.Documents.Run("  < $parentDisplay")
        $runParent.Foreground = New-ColorBrush $tc.Overlay0
        $runParent.FontSize = 10
        $title.Inlines.Add($runParent) | Out-Null
    } else {
        $title.Text = $taskTitleForDisplay
    }

    [System.Windows.Controls.Grid]::SetColumn($title, 1)
    $row.Children.Add($title) | Out-Null

    $due = New-Object System.Windows.Controls.TextBlock
    $due.Text = $Task.DueText
    $due.Foreground = New-ColorBrush $tc.Subtext0
    $due.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $due.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $due.LineStackingStrategy = [System.Windows.LineStackingStrategy]::BlockLineHeight
    $due.LineHeight = 18
    $due.Margin = New-Object System.Windows.Thickness(8, 0, 8, 0)
    [System.Windows.Controls.Grid]::SetColumn($due, 2)
    $row.Children.Add($due) | Out-Null

    $doneBtn = New-Object System.Windows.Controls.Button
    $doneBtn.Content = [string][char]0x2713
    $baseDoneBtnStyle = $Window.TryFindResource("CardButton")
    if ($null -eq $baseDoneBtnStyle) {
        $baseDoneBtnStyle = $Window.TryFindResource("SmallButton")
    }

    if ($null -ne $baseDoneBtnStyle) {
        $doneBtnStyle = New-Object System.Windows.Style([System.Windows.Controls.Button], $baseDoneBtnStyle)

        $doneRel = New-Object System.Windows.Data.RelativeSource([System.Windows.Data.RelativeSourceMode]::FindAncestor)
        $doneRel.AncestorType = [System.Windows.Controls.ListBoxItem]
        $doneRel.AncestorLevel = 1

        $doneSelBinding = New-Object System.Windows.Data.Binding
        $doneSelBinding.RelativeSource = $doneRel
        $doneSelBinding.Path = New-Object System.Windows.PropertyPath("IsSelected")

        $doneSelTrigger = New-Object System.Windows.DataTrigger
        $doneSelTrigger.Binding = $doneSelBinding
        $doneSelTrigger.Value = $true
        $doneSelTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, (New-ColorBrush $tc.Surface2)))) | Out-Null
        $doneSelTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty, (New-ColorBrush $tc.Overlay0)))) | Out-Null
        $doneSelTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, (New-Object System.Windows.Thickness(1))))) | Out-Null
        $doneBtnStyle.Triggers.Add($doneSelTrigger) | Out-Null

        $doneHoverBinding = New-Object System.Windows.Data.Binding
        $doneHoverBinding.RelativeSource = $doneRel
        $doneHoverBinding.Path = New-Object System.Windows.PropertyPath("IsMouseOver")

        $doneHoverTrigger = New-Object System.Windows.DataTrigger
        $doneHoverTrigger.Binding = $doneHoverBinding
        $doneHoverTrigger.Value = $true
        $doneHoverTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, (New-ColorBrush $tc.Surface2)))) | Out-Null
        $doneHoverTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty, (New-ColorBrush $tc.Overlay0)))) | Out-Null
        $doneHoverTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, (New-Object System.Windows.Thickness(1))))) | Out-Null
        $doneBtnStyle.Triggers.Add($doneHoverTrigger) | Out-Null

        $doneFocusBinding = New-Object System.Windows.Data.Binding
        $doneFocusBinding.RelativeSource = $doneRel
        $doneFocusBinding.Path = New-Object System.Windows.PropertyPath("IsKeyboardFocusWithin")

        $doneFocusTrigger = New-Object System.Windows.DataTrigger
        $doneFocusTrigger.Binding = $doneFocusBinding
        $doneFocusTrigger.Value = $true
        $doneFocusTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, (New-ColorBrush $tc.Surface2)))) | Out-Null
        $doneFocusTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty, (New-ColorBrush $tc.Overlay0)))) | Out-Null
        $doneFocusTrigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, (New-Object System.Windows.Thickness(1))))) | Out-Null
        $doneBtnStyle.Triggers.Add($doneFocusTrigger) | Out-Null

        $doneBtn.Style = $doneBtnStyle
    }
    else {
        $doneBtn.Background = New-ColorBrush $tc.Surface1
        $doneBtn.Foreground = New-ColorBrush $tc.Text
        $doneBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    }
    $doneBtn.Width = 30
    $doneBtn.Height = 30
    $doneBtn.MinWidth = 30
    $doneBtn.Padding = New-Object System.Windows.Thickness(0)
    $doneBtn.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
    $doneBtn.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    $doneBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $doneBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $doneBtn.Margin = New-Object System.Windows.Thickness(4, 1, 0, 0)
    $doneBtn.ToolTip = "Mark Asana task complete"
    $doneBtn.IsEnabled = -not [string]::IsNullOrWhiteSpace([string]$Task.AsanaTaskGid)
    $doneBtn.Tag = @{
        Window      = $Window
        ProjectName = $Task.ProjectDisplayName
        TaskTitle   = $Task.Title
        TaskGid     = $Task.AsanaTaskGid
        Row         = $row
    }
    $doneBtn.Add_Click({
        param($sender, $e)
        try {
            $d = $sender.Tag
            $win = $d.Window
            $title = [string]$d.TaskTitle
            $gid = [string]$d.TaskGid

            if ([string]::IsNullOrWhiteSpace($gid)) {
                [System.Windows.MessageBox]::Show(
                    "Asana task GID not found.",
                    "Dashboard Queue",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
                return
            }

            $confirmed = Show-ConfirmDoneDialog -ProjectName $d.ProjectName -TaskTitle $title -Owner $win
            if (-not $confirmed) { return }

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

            $status = $win.FindName("lblDashTodayQueueStatus")
            if ($null -ne $status) {
                $status.Text = "Dashboard Queue: Done synced to Asana. Running Asana Sync..."
            }

            $list = $win.FindName("lstDashTodayQueue")
            if ($null -ne $list -and $null -ne $d.Row) {
                [void]$list.Items.Remove($d.Row)
            }

            if (Get-Command Invoke-AsanaSync -ErrorAction SilentlyContinue) {
                try {
                    Invoke-AsanaSync
                    Start-DashboardRefreshAfterAsanaSync -Window $win
                }
                catch {
                    if ($null -ne $status) {
                        $status.Text = "Dashboard Queue: Done synced to Asana. Sync refresh failed."
                    }
                }
            }
            else {
                if ($null -ne $status) {
                    $status.Text = "Dashboard Queue: Done synced to Asana. Run Asana Sync to refresh."
                }
            }
        }
        catch {
            [System.Windows.MessageBox]::Show($_.Exception.Message, "Error") | Out-Null
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($doneBtn, 5)
    $row.Children.Add($doneBtn) | Out-Null

    # Open in Asana button
    $openBtn = New-Object System.Windows.Controls.Button
    $openBtn.Content = [string][char]0x2197
    $baseOpenStyle = $Window.TryFindResource("CardButton")
    if ($null -eq $baseOpenStyle) { $baseOpenStyle = $Window.TryFindResource("SmallButton") }

    if ($null -ne $baseOpenStyle) {
        $openBtnStyle = New-Object System.Windows.Style([System.Windows.Controls.Button], $baseOpenStyle)

        $openRel = New-Object System.Windows.Data.RelativeSource([System.Windows.Data.RelativeSourceMode]::FindAncestor)
        $openRel.AncestorType = [System.Windows.Controls.ListBoxItem]
        $openRel.AncestorLevel = 1

        foreach ($prop in @("IsSelected", "IsMouseOver", "IsKeyboardFocusWithin")) {
            $binding = New-Object System.Windows.Data.Binding
            $binding.RelativeSource = $openRel
            $binding.Path = New-Object System.Windows.PropertyPath($prop)
            $trigger = New-Object System.Windows.DataTrigger
            $trigger.Binding = $binding
            $trigger.Value = $true
            $trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty,    (New-ColorBrush $tc.Surface2)))) | Out-Null
            $trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty,    (New-ColorBrush $tc.Overlay0)))) | Out-Null
            $trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, (New-Object System.Windows.Thickness(1))))) | Out-Null
            $openBtnStyle.Triggers.Add($trigger) | Out-Null
        }
        $openBtn.Style = $openBtnStyle
    }
    $openBtn.Width = 30
    $openBtn.Height = 30
    $openBtn.MinWidth = 30
    $openBtn.Padding = New-Object System.Windows.Thickness(0)
    $openBtn.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
    $openBtn.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    $openBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $openBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $openBtn.Margin = New-Object System.Windows.Thickness(4, 1, 0, 0)
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
    [System.Windows.Controls.Grid]::SetColumn($openBtn, 3)
    $row.Children.Add($openBtn) | Out-Null

    # Snooze button
    $snoozeBtn = New-Object System.Windows.Controls.Button
    $snoozeBtn.Content = "z"
    $baseSnoozeStyle = $Window.TryFindResource("CardButton")
    if ($null -eq $baseSnoozeStyle) { $baseSnoozeStyle = $Window.TryFindResource("SmallButton") }

    if ($null -ne $baseSnoozeStyle) {
        $snoozeBtnStyle = New-Object System.Windows.Style([System.Windows.Controls.Button], $baseSnoozeStyle)

        $snzRel = New-Object System.Windows.Data.RelativeSource([System.Windows.Data.RelativeSourceMode]::FindAncestor)
        $snzRel.AncestorType = [System.Windows.Controls.ListBoxItem]
        $snzRel.AncestorLevel = 1

        foreach ($prop in @("IsSelected", "IsMouseOver", "IsKeyboardFocusWithin")) {
            $binding = New-Object System.Windows.Data.Binding
            $binding.RelativeSource = $snzRel
            $binding.Path = New-Object System.Windows.PropertyPath($prop)
            $trigger = New-Object System.Windows.DataTrigger
            $trigger.Binding = $binding
            $trigger.Value = $true
            $trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty,    (New-ColorBrush $tc.Surface2)))) | Out-Null
            $trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty,    (New-ColorBrush $tc.Overlay0)))) | Out-Null
            $trigger.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, (New-Object System.Windows.Thickness(1))))) | Out-Null
            $snoozeBtnStyle.Triggers.Add($trigger) | Out-Null
        }
        $snoozeBtn.Style = $snoozeBtnStyle
    }
    else {
        $snoozeBtn.Background = New-ColorBrush $tc.Surface1
        $snoozeBtn.Foreground = New-ColorBrush $tc.Subtext1
        $snoozeBtn.BorderThickness = New-Object System.Windows.Thickness(0)
    }
    $snoozeBtn.Width = 30
    $snoozeBtn.Height = 30
    $snoozeBtn.MinWidth = 30
    $snoozeBtn.Padding = New-Object System.Windows.Thickness(0)
    $snoozeBtn.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
    $snoozeBtn.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
    $snoozeBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $snoozeBtn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $snoozeBtn.Margin = New-Object System.Windows.Thickness(4, 1, 0, 0)
    $snoozeBtn.ToolTip = "Snooze until tomorrow"
    $snoozeBtn.Tag = @{ Window = $Window; Key = (Get-TodayQueueSnoozeKey -Task $Task) }
    $snoozeBtn.Add_Click({
        param($sender, $e)
        try {
            $d = $sender.Tag
            Add-TodayQueueSnooze -Key $d.Key
            Update-DashboardTodayQueueWidget -Window $d.Window
        }
        catch {
            [System.Windows.MessageBox]::Show($_.Exception.Message, "Error") | Out-Null
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($snoozeBtn, 4)
    $row.Children.Add($snoozeBtn) | Out-Null

    return $row
}

function Update-DashboardTodayQueueWidget {
    param([System.Windows.Window]$Window)

    $queueBorder = $Window.FindName("bdDashTodayQueue")
    if ($null -ne $queueBorder -and $queueBorder.Visibility -ne [System.Windows.Visibility]::Visible) { return }

    $list = $Window.FindName("lstDashTodayQueue")
    $status = $Window.FindName("lblDashTodayQueueStatus")
    if ($null -eq $list -or $null -eq $status) { return }
    $isListMode = ([string]$script:DashboardTodayQueueViewMode -eq "List")
    $list.MaxHeight = if ($isListMode) { 420 } else { 170 }

    $list.Items.Clear()
    $status.Text = "Dashboard Queue: Loading..."

    try {
        $required = @(
            "Get-TodayQueueTasksFromProject",
            "Get-TodayQueuePriority",
            "Select-TodayQueueProjectInEditor",
            "Invoke-TodayQueueCompleteAsanaTask"
        )
        foreach ($name in $required) {
            if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
                $status.Text = "Dashboard Queue: TodayQueue module unavailable."
                return
            }
        }

        $projects = if ($null -ne $script:ProjectInfoCache) { $script:ProjectInfoCache } else { @(Get-ProjectInfoList -SkipTokens) }
        $allTasks = @()
        foreach ($p in $projects) {
            $allTasks += @(Get-TodayQueueTasksFromProject -ProjectInfo $p)
        }

        if ($allTasks.Count -eq 0) {
            $status.Text = "Dashboard Queue: No in-progress tasks."
            Update-UnsnoozeButton -Window $Window -Count 0
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

        # Filter snoozed tasks
        $visibleTasks = @($sorted | Where-Object { -not (Test-TodayQueueSnoozed -Key (Get-TodayQueueSnoozeKey -Task $_)) })
        $totalVisible = $visibleTasks.Count
        $snoozeCount  = $sorted.Count - $totalVisible

        if ($totalVisible -eq 0) {
            $msg = if ($snoozeCount -gt 0) { "Dashboard Queue: All tasks snoozed ($snoozeCount)." } else { "Dashboard Queue: No in-progress tasks." }
            $status.Text = $msg
            Update-UnsnoozeButton -Window $Window -Count $snoozeCount
            return
        }

        if ($isListMode) {
            $listMax = [int]$script:DashboardTodayQueueListMaxItems
            if ($listMax -lt 1) { $listMax = 300 }
            $showCount = [Math]::Min($listMax, $totalVisible)
            for ($i = 0; $i -lt $showCount; $i++) {
                [void]$list.Items.Add((New-DashboardTodayQueueCompactListItem -Task $visibleTasks[$i]))
            }
            $statusMsg = "Dashboard Queue (List): $totalVisible tasks (showing $showCount)"
            if ($snoozeCount -gt 0) { $statusMsg += ", $snoozeCount snoozed" }
            $status.Text = $statusMsg
        }
        else {
            $queueLimit = [int]$script:AppState.DashboardTodayQueueLimit
            $showCount = [Math]::Min($queueLimit, $totalVisible)
            $lastBucketGroup = -1

            for ($i = 0; $i -lt $showCount; $i++) {
                $t = $visibleTasks[$i]
                $bucket = [int]$t.SortBucket
                $bucketGroup = if ($bucket -le 1) { $bucket } elseif ($bucket -le 3) { 2 } elseif ($bucket -eq 4) { 3 } else { 4 }
                if ($bucketGroup -ne $lastBucketGroup) {
                    $sectionLabel = switch ($bucketGroup) {
                        0 { "Overdue" }
                        1 { "Today" }
                        2 { "This Week" }
                        3 { "Later" }
                        default { "No Due" }
                    }
                    [void]$list.Items.Add((New-DashboardQueueSectionHeader -Label $sectionLabel))
                    $lastBucketGroup = $bucketGroup
                }
                [void]$list.Items.Add((New-DashboardTodayQueueListItem -Task $t -Window $Window))
            }

            $remaining = $totalVisible - $showCount
            if ($remaining -gt 0) {
                [void]$list.Items.Add((New-DashboardQueueShowMoreItem -Window $Window -Tasks @($visibleTasks[$showCount..($totalVisible - 1)]) -LastBucketGroup $lastBucketGroup -TotalVisible $totalVisible -SnoozeCount $snoozeCount))
            }

            $statusMsg = "Dashboard Queue: $totalVisible tasks (showing $showCount)"
            if ($snoozeCount -gt 0) { $statusMsg += ", $snoozeCount snoozed" }
            $status.Text = $statusMsg
        }

        Update-UnsnoozeButton -Window $Window -Count $snoozeCount
    }
    catch {
        $status.Text = "Dashboard Queue: Failed to load."
    }
}

function Set-DashboardTodayQueueVisibility {
    param([System.Windows.Window]$Window)

    $queueBorder = $Window.FindName("bdDashTodayQueue")
    $btnToggle = $Window.FindName("btnDashToggleTodayQueue")
    if ($null -eq $queueBorder) { return $false }

    $isVisible = $true
    try {
        if ($script:AppState -is [hashtable] -and $script:AppState.ContainsKey("DashboardTodayQueueVisible")) {
            $isVisible = [bool]$script:AppState["DashboardTodayQueueVisible"]
        }
        elseif ($null -ne $script:AppState.DashboardTodayQueueVisible) {
            $isVisible = [bool]$script:AppState.DashboardTodayQueueVisible
        }
    }
    catch { $isVisible = $true }

    $queueBorder.Visibility = if ($isVisible) {
        [System.Windows.Visibility]::Visible
    }
    else {
        [System.Windows.Visibility]::Collapsed
    }

    if ($null -ne $btnToggle) {
        $btnToggle.Content = if ($isVisible) { "$([char]0x25BE)" } else { "$([char]0x25B8)" }
    }

    return $isVisible
}

function Toggle-DashboardTodayQueue {
    param([System.Windows.Window]$Window)

    $queueBorder = $Window.FindName("bdDashTodayQueue")
    if ($null -eq $queueBorder) { return }

    $currentVisible = ($queueBorder.Visibility -eq [System.Windows.Visibility]::Visible)
    $nextVisible = -not $currentVisible

    # Apply to UI first so user always gets immediate feedback.
    $queueBorder.Visibility = if ($nextVisible) {
        [System.Windows.Visibility]::Visible
    }
    else {
        [System.Windows.Visibility]::Collapsed
    }

    if ($script:AppState -is [hashtable]) {
        $script:AppState["DashboardTodayQueueVisible"] = [bool]$nextVisible
    }
    else {
        $script:AppState.DashboardTodayQueueVisible = [bool]$nextVisible
    }

    $null = Set-DashboardTodayQueueVisibility -Window $Window
    if ($nextVisible) {
        Update-DashboardTodayQueueWidget -Window $Window
    }

    try { Save-AppSettings } catch {}
}

function Initialize-TabDashboard {
    param([System.Windows.Window]$Window, [string]$ScriptDir)

    $ensureStatus = {
        param([System.Windows.Window]$w)
        if ($null -eq $w) { return }
        $sp = $w.FindName("statusProject")
        if ($null -ne $sp -and [string]::IsNullOrWhiteSpace([string]$sp.Text)) {
            $sp.Text = "Ready"
        }
    }

    Load-TodayQueueSnooze
    Update-DashboardTodayQueueModeButton -Window $Window

    # Initial load: synchronous fast scan (no tokens) so cache contains plain Hashtables.
    # Must NOT use Start-DashboardAsyncRefresh here - runspace results are Deserialized.Hashtable
    # which breaks dot-notation access ($p.FocusFile etc.) used later when building token file list.
    Update-Dashboard -Window $Window -FilterText "" -ShowHidden $false -ScriptDir $ScriptDir
    & $ensureStatus $Window
    $queueVisible = Set-DashboardTodayQueueVisibility -Window $Window
    if ($queueVisible) {
        Update-DashboardTodayQueueWidget -Window $Window
    }
    
    $btnDashRefresh = $Window.FindName("btnDashRefresh")
    $txtDashFilter = $Window.FindName("txtDashFilter")
    $chkShowHidden = $Window.FindName("chkShowHidden")
    
    if ($null -ne $btnDashRefresh) {
        $btnDashRefresh.Add_Click({
                $win = $Window
                $btn = $win.FindName("btnDashRefresh")
                if ($null -ne $btn) {
                    $btn.IsEnabled = $false
                    $btn.Content = "Loading..."
                }
                $filter = $win.FindName("txtDashFilter").Text
                $showHidden = [bool]($win.FindName("chkShowHidden").IsChecked)
                try {
                    Update-Dashboard -Window $win -FilterText $filter -ShowHidden $showHidden -Force -ScriptDir $ScriptDir
                    Update-DashboardTodayQueueWidget -Window $win
                }
                finally {
                    if ($null -ne $btn) {
                        $btn.IsEnabled = $true
                        $btn.Content = "Refresh"
                    }
                }
            }.GetNewClosure())
    }

    $btnDashToggleQueue = $Window.FindName("btnDashToggleTodayQueue")
    if ($null -ne $btnDashToggleQueue) {
        $btnDashToggleQueue.Add_Click({
                Toggle-DashboardTodayQueue -Window $Window
            }.GetNewClosure())
    }

    $lblDashQueueTitle = $Window.FindName("lblDashQueueTitle")
    if ($null -ne $lblDashQueueTitle) {
        $lblDashQueueTitle.Add_MouseLeftButtonUp({
                Toggle-DashboardTodayQueue -Window $Window
            }.GetNewClosure())
    }

    $btnDashQueueRefresh = $Window.FindName("btnDashTodayQueueRefresh")
    if ($null -ne $btnDashQueueRefresh) {
        $btnDashQueueRefresh.Add_Click({
                Update-DashboardTodayQueueWidget -Window $Window
            }.GetNewClosure())
    }

    $btnDashQueueViewMode = $Window.FindName("btnDashTodayQueueViewMode")
    if ($null -ne $btnDashQueueViewMode) {
        $btnDashQueueViewMode.Add_Click({
                Toggle-DashboardTodayQueueViewMode -Window $Window
            }.GetNewClosure())
    }

    $btnDashUnsnooze = $Window.FindName("btnDashUnsnooze")
    if ($null -ne $btnDashUnsnooze) {
        $btnDashUnsnooze.Add_Click({
                try {
                    $win = $Window
                    Clear-TodayQueueSnooze
                    Save-TodayQueueSnooze
                    Update-DashboardTodayQueueWidget -Window $win
                }
                catch {
                    [System.Windows.MessageBox]::Show($_.Exception.Message, "Unsnooze Error") | Out-Null
                }
            }.GetNewClosure())
    }
    
    if ($null -ne $txtDashFilter) {
        $txtDashFilter.Add_TextChanged({
                $win = $Window
                $filter = $win.FindName("txtDashFilter").Text
                $showHidden = [bool]($win.FindName("chkShowHidden").IsChecked)
                Update-Dashboard -Window $win -FilterText $filter -ShowHidden $showHidden -ScriptDir $ScriptDir
            }.GetNewClosure())
    }
    
    if ($null -ne $chkShowHidden) {
        $chkShowHidden.Add_Click({
                $win = $Window
                $filter = $win.FindName("txtDashFilter").Text
                $showHidden = [bool]($win.FindName("chkShowHidden").IsChecked)
                Update-Dashboard -Window $win -FilterText $filter -ShowHidden $showHidden -ScriptDir $ScriptDir
            }.GetNewClosure())
    }
    
    $tabMain = $Window.FindName("tabMain")
    if ($null -ne $tabMain) {
        $tabMain.Add_SelectionChanged({
                param($s, $e)
                if ($e.OriginalSource -ne $s) { return }
                $win = $Window
                $statLbl = $win.FindName("lblDashStats")
                $statProject = $win.FindName("statusProject")
                if ($s.SelectedIndex -eq 0) {
                    if ($null -ne $statLbl -and -not [string]::IsNullOrWhiteSpace([string]$statLbl.Text)) {
                        $statLbl.Visibility = [System.Windows.Visibility]::Visible
                        if ($null -ne $statProject) { $statProject.Visibility = [System.Windows.Visibility]::Collapsed }
                    }
                    else {
                        if ($null -ne $statProject) { $statProject.Visibility = [System.Windows.Visibility]::Visible }
                        if ($null -ne $statLbl) { $statLbl.Visibility = [System.Windows.Visibility]::Collapsed }
                    }
                }
                else {
                    if ($null -ne $statLbl) { $statLbl.Visibility = [System.Windows.Visibility]::Collapsed }
                    if ($null -ne $statProject) { $statProject.Visibility = [System.Windows.Visibility]::Collapsed }
                }
                $isEditor = ($s.SelectedIndex -eq 1)
                $editorVis = if ($isEditor) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
                foreach ($ctrlName in @("statusFile","statusHealth","statusEncoding","statusDirty")) {
                    $ctrl = $win.FindName($ctrlName)
                    if ($null -ne $ctrl) { $ctrl.Visibility = $editorVis }
                }
                if ($s.SelectedIndex -eq 0) {
                    & $ensureStatus $win
                    $filter = $win.FindName("txtDashFilter").Text
                    $showHidden = [bool]($win.FindName("chkShowHidden").IsChecked)
                    Update-Dashboard -Window $win -FilterText $filter -ShowHidden $showHidden -ScriptDir $ScriptDir
                    Update-DashboardTodayQueueWidget -Window $win
                }
            }.GetNewClosure())
    }

    Start-DashboardAutoRefreshTimer -Window $Window
}
