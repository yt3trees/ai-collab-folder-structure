# TabDashboard.ps1 - Dashboard tab: project cards with freshness indicators

# ---- Dashboard state tracking (skip unnecessary card rebuilds) ----
$script:DashLastFilter     = $null
$script:DashLastShowHidden = $null
$script:DashLastBuildTime  = [datetime]::MinValue
$script:DashLoadInProgress = $false

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
    $card.MinHeight = 160
    $card.Margin = New-Object System.Windows.Thickness(0, 0, 8, 8)
    $card.Background = New-ColorBrush $c.Surface0
    $card.BorderBrush = New-ColorBrush $c.Surface1
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
            $tabMain.SelectedIndex = 2
            $e.Handled = $true
        })
    $stack.Children.Add($activityGroup) | Out-Null

    # --- Action buttons ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)

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

    # [Check] button
    $btnCheck = &$createCardButton "Check" (New-Object System.Windows.Thickness(0, 0, 6, 0))
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
    $btnEdit = &$createCardButton "Edit" (New-Object System.Windows.Thickness(0, 0, 0, 0))
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
    $btnTerm = &$createCardButton "Term" (New-Object System.Windows.Thickness(6, 0, 0, 0))
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
    $btnDir = &$createCardButton "Dir" (New-Object System.Windows.Thickness(6, 0, 0, 0))
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

    $btnPanel.Children.Add($btnCheck) | Out-Null
    $btnPanel.Children.Add($btnEdit)  | Out-Null
    $btnPanel.Children.Add($btnDir)   | Out-Null
    $btnPanel.Children.Add($btnTerm)  | Out-Null
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

# ---- Async data loader: runs file I/O in background runspace, builds cards on UI thread ----

function Start-DashboardLoadAsync {
    param(
        [System.Windows.Window]$Window,
        [string]$FilterText,
        [bool]$ShowHidden,
        [string]$ScriptDir
    )

    $script:DashLoadInProgress = $true

    # Python check (independent of Get-ProjectInfoList having been called before)
    $pythonTokenScript = Join-Path $script:AppState.ScriptDir "get_tokens.py"
    $hasPython = ($null -ne (Get-Command python -ErrorAction SilentlyContinue)) -and (Test-Path $pythonTokenScript)

    # Shared result bag (passed by .NET reference to background runspace - no serialization)
    $resultBag = New-Object 'System.Collections.Concurrent.ConcurrentBag[object]'

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = [System.Threading.ApartmentState]::MTA
    $rs.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::Default
    $rs.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs

    # Self-contained data gathering script (no dependency on main runspace functions)
    $gatherScript = {
        param($WorkspaceRoot, $PythonTokenScript, $HasPython, $ResultBag)

        function Get-FileAgeDays { param([string]$Path)
            if (Test-Path $Path) { return [int]((Get-Date) - (Get-Item $Path).LastWriteTime).TotalDays }
            return $null
        }
        function Get-JunctionStatus { param([string]$Path)
            if (-not (Test-Path $Path)) { return "Missing" }
            $item = Get-Item $Path -ErrorAction SilentlyContinue
            if ($null -eq $item) { return "Missing" }
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                $children = Get-ChildItem $Path -ErrorAction SilentlyContinue
                if ($null -eq $children -and -not (Test-Path "$Path\.")) { return "Broken" }
                return "OK"
            }
            return "OK"
        }
        function Get-FileMetrics { param([string]$Path)
            if (-not (Test-Path $Path)) { return $null }
            try {
                $item = Get-Item $Path
                if ($item.Length -eq 0) { return @{ Lines = 0 } }
                $lines = (Get-Content $Path -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
                return @{ Lines = $lines }
            } catch { return $null }
        }
        function Get-DecisionLogCount { param([string]$AiCtx)
            $logDir = Join-Path $AiCtx "context\decision_log"
            if (-not (Test-Path $logDir)) { return 0 }
            return (Get-ChildItem $logDir -Filter "*.md" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne "TEMPLATE.md" } | Measure-Object).Count
        }
        function Get-FocusHistoryDates { param([string]$AiCtx)
            $histDir = Join-Path $AiCtx "context\focus_history"
            if (-not (Test-Path $histDir)) { return @() }
            $dates = @()
            Get-ChildItem $histDir -Filter "*.md" -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.BaseName -match '^\d{4}-\d{2}-\d{2}$') {
                    $dates += [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
                }
            }
            return ($dates | Sort-Object)
        }
        function Get-DecisionLogDates { param([string]$AiCtx)
            $logDir = Join-Path $AiCtx "context\decision_log"
            if (-not (Test-Path $logDir)) { return @() }
            $dates = @()
            Get-ChildItem $logDir -Filter "*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "TEMPLATE.md" } | ForEach-Object {
                if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})_') {
                    $dates += [datetime]::ParseExact($Matches[1], "yyyy-MM-dd", $null)
                }
            }
            return ($dates | Sort-Object)
        }
        function New-ProjInfo { param([string]$Name, [string]$Path, [string]$Tier, [string]$Category = "project")
            $aiCtx        = Join-Path $Path "_ai-context"
            $aiCtxContent = Join-Path $aiCtx "context"
            $focusFile    = Join-Path $aiCtxContent "current_focus.md"
            $summaryFile  = Join-Path $aiCtxContent "project_summary.md"
            $fileMapFile  = Join-Path $aiCtxContent "file_map.md"
            $agentsFile   = Join-Path $Path "AGENTS.md"
            $claudeFile   = Join-Path $Path "CLAUDE.md"
            $fm = Get-FileMetrics $focusFile
            $sm = Get-FileMetrics $summaryFile
            return @{
                Name = $Name; Tier = $Tier; Category = $Category; Path = $Path
                AiContextPath = $aiCtx; AiContextContentPath = $aiCtxContent
                JunctionShared   = Get-JunctionStatus (Join-Path $Path "shared")
                JunctionObsidian = Get-JunctionStatus (Join-Path $aiCtx "obsidian_notes")
                JunctionContext  = Get-JunctionStatus $aiCtxContent
                FocusFile    = if (Test-Path $focusFile)   { $focusFile }   else { $null }
                SummaryFile  = if (Test-Path $summaryFile) { $summaryFile } else { $null }
                FileMapFile  = if (Test-Path $fileMapFile) { $fileMapFile } else { $null }
                AgentsFile   = if (Test-Path $agentsFile)  { $agentsFile }  else { $null }
                ClaudeFile   = if (Test-Path $claudeFile)  { $claudeFile }  else { $null }
                FocusLines   = if ($null -ne $fm) { $fm.Lines } else { $null }
                SummaryLines = if ($null -ne $sm) { $sm.Lines } else { $null }
                FocusTokens = $null; SummaryTokens = $null
                FocusAge   = Get-FileAgeDays $focusFile
                SummaryAge = Get-FileAgeDays $summaryFile
                DecisionLogCount  = Get-DecisionLogCount $aiCtx
                FocusHistoryDates = Get-FocusHistoryDates $aiCtx
                DecisionLogDates  = Get-DecisionLogDates $aiCtx
            }
        }

        $projects = [System.Collections.Generic.List[object]]::new()

        # Full-tier
        Get-ChildItem -Path $WorkspaceRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq '_INHOUSE' -or $_.Name -notmatch '^[_\.]' } |
        ForEach-Object { $projects.Add((New-ProjInfo -Name $_.Name -Path $_.FullName -Tier "full")) }

        # Mini-tier
        $miniDir = Join-Path $WorkspaceRoot "_mini"
        if (Test-Path $miniDir) {
            Get-ChildItem -Path $miniDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]' } |
            ForEach-Object { $projects.Add((New-ProjInfo -Name $_.Name -Path $_.FullName -Tier "mini")) }
        }

        # Domain
        $domainsDir = Join-Path $WorkspaceRoot "_domains"
        if (Test-Path $domainsDir) {
            Get-ChildItem -Path $domainsDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]' } |
            ForEach-Object { $projects.Add((New-ProjInfo -Name $_.Name -Path $_.FullName -Tier "full" -Category "domain")) }

            $domainMiniDir = Join-Path $domainsDir "_mini"
            if (Test-Path $domainMiniDir) {
                Get-ChildItem -Path $domainMiniDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '^[_\.]' } |
                ForEach-Object { $projects.Add((New-ProjInfo -Name $_.Name -Path $_.FullName -Tier "mini" -Category "domain")) }
            }
        }

        # Bulk token calculation via Python
        if ($HasPython -and (Test-Path $PythonTokenScript)) {
            $filesToCount = @()
            foreach ($p in $projects) {
                if ($null -ne $p.FocusFile)   { $filesToCount += $p.FocusFile }
                if ($null -ne $p.SummaryFile) { $filesToCount += $p.SummaryFile }
            }
            if ($filesToCount.Count -gt 0) {
                $pyOut = & python $PythonTokenScript @("--files") @filesToCount 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($pyOut)) {
                    try {
                        $tokenData = @{}
                        ($pyOut | ConvertFrom-Json).PSObject.Properties |
                            ForEach-Object { $tokenData[$_.Name.ToLowerInvariant()] = $_.Value }
                        foreach ($p in $projects) {
                            if ($null -ne $p.FocusFile) {
                                $k = $p.FocusFile.ToLowerInvariant()
                                if ($tokenData.ContainsKey($k)) { $p.FocusTokens = $tokenData[$k] }
                            }
                            if ($null -ne $p.SummaryFile) {
                                $k = $p.SummaryFile.ToLowerInvariant()
                                if ($tokenData.ContainsKey($k)) { $p.SummaryTokens = $tokenData[$k] }
                            }
                        }
                    } catch {}
                }
            }
        }

        foreach ($p in $projects) { $ResultBag.Add($p) }
    }

    $ps.AddScript($gatherScript).
        AddParameter("WorkspaceRoot",     $script:AppState.WorkspaceRoot).
        AddParameter("PythonTokenScript", $pythonTokenScript).
        AddParameter("HasPython",         $hasPython).
        AddParameter("ResultBag",         $resultBag) | Out-Null

    # BeginInvoke returns IAsyncResult whose IsCompleted is thread-safe to poll
    $asyncResult = $ps.BeginInvoke()

    # DispatcherTimer polls on the UI thread (= main PS runspace thread).
    # Avoids [System.AsyncCallback] delegate issues across PS runspace boundaries.
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)

    $cap = @{
        Window      = $Window
        Filter      = $FilterText
        ShowHidden  = $ShowHidden
        ScriptDir   = $ScriptDir
        ResultBag   = $resultBag
        Ps          = $ps
        Rs          = $rs
        AsyncResult = $asyncResult
        Timer       = $timer
    }

    $timer.Add_Tick({
        if (-not $cap.AsyncResult.IsCompleted) { return }
        $cap.Timer.Stop()

        try { $cap.Ps.EndInvoke($cap.AsyncResult) } catch {}

        try {
            $loadedProjects = @($cap.ResultBag) | Sort-Object { $_.Name }

            $script:ProjectInfoCache     = $loadedProjects
            $script:ProjectInfoCacheTime = Get-Date
            $script:AppState.Projects    = $loadedProjects

            $script:DashLastFilter       = $cap.Filter
            $script:DashLastShowHidden   = $cap.ShowHidden
            $script:DashLastBuildTime    = $script:ProjectInfoCacheTime

            $cardsPanel = $cap.Window.FindName("dashboardCards")
            if ($null -ne $cardsPanel) {
                $cardsPanel.Children.Clear()
                $filter = $cap.Filter.Trim().ToLower()
                foreach ($proj in $loadedProjects) {
                    $isHidden = Test-ProjectHidden -Info $proj
                    if ($isHidden -and -not $cap.ShowHidden) { continue }
                    if ($filter -ne "" -and $proj.Name.ToLower() -notlike "*$filter*") { continue }
                    $cardsPanel.Children.Add(
                        (New-ProjectCard -Info $proj -Window $cap.Window -IsHidden $isHidden -ScriptDir $cap.ScriptDir)
                    ) | Out-Null
                }
            }
        } finally {
            $script:DashLoadInProgress = $false
            try { $cap.Ps.Dispose() } catch {}
            try { $cap.Rs.Close(); $cap.Rs.Dispose() } catch {}
        }
    }.GetNewClosure())

    $timer.Start()
}

function Update-Dashboard {
    param([System.Windows.Window]$Window, [string]$FilterText = "", [bool]$ShowHidden = $false, [switch]$Force, [string]$ScriptDir = "")
    $cardsPanel = $Window.FindName("dashboardCards")
    if ($null -eq $cardsPanel) { return }

    # Skip rebuild if cache is fresh and nothing has changed
    if (-not $Force) {
        $cacheIsFresh = ($null -ne $script:ProjectInfoCache) -and
            (((Get-Date) - $script:ProjectInfoCacheTime).TotalSeconds -lt $script:ProjectInfoCacheTTL)
        $builtFromCurrentCache = ($script:DashLastBuildTime -ne [datetime]::MinValue) -and
            ($script:DashLastBuildTime -ge $script:ProjectInfoCacheTime)
        $nothingChanged = ($FilterText -eq $script:DashLastFilter) -and
            ($ShowHidden -eq $script:DashLastShowHidden) -and
            $builtFromCurrentCache
        if ($cacheIsFresh -and $nothingChanged -and $cardsPanel.Children.Count -gt 0) {
            return
        }
    }

    $cacheIsStale = ($null -eq $script:ProjectInfoCache) -or $Force -or
        (((Get-Date) - $script:ProjectInfoCacheTime).TotalSeconds -ge $script:ProjectInfoCacheTTL)

    if ($cacheIsStale) {
        # Async path: show loading indicator and run I/O in background
        if (-not $script:DashLoadInProgress) {
            $cardsPanel.Children.Clear()
            $tc = Get-ThemeColors -ThemeName $script:AppState.Theme
            $loadingBlock = New-Object System.Windows.Controls.TextBlock
            $loadingBlock.Text = "Loading projects..."
            $loadingBlock.Foreground = New-ColorBrush $tc.Subtext1
            $loadingBlock.FontSize = 13
            $loadingBlock.Margin = New-Object System.Windows.Thickness(12)
            $cardsPanel.Children.Add($loadingBlock) | Out-Null
            Start-DashboardLoadAsync -Window $Window -FilterText $FilterText -ShowHidden $ShowHidden -ScriptDir $ScriptDir
        }
        return
    }

    # Cache is fresh - build cards synchronously (fast, no I/O)
    $script:DashLastFilter     = $FilterText
    $script:DashLastShowHidden = $ShowHidden
    $script:DashLastBuildTime  = $script:ProjectInfoCacheTime

    $cardsPanel.Children.Clear()
    $filter = $FilterText.Trim().ToLower()
    foreach ($proj in $script:ProjectInfoCache) {
        $isHidden = Test-ProjectHidden -Info $proj
        if ($isHidden -and -not $ShowHidden) { continue }
        if ($filter -ne "" -and $proj.Name.ToLower() -notlike "*$filter*") { continue }
        $cardsPanel.Children.Add((New-ProjectCard -Info $proj -Window $Window -IsHidden $isHidden -ScriptDir $ScriptDir)) | Out-Null
    }
}

function Initialize-TabDashboard {
    param([System.Windows.Window]$Window, [string]$ScriptDir)
    
    # Initial load
    Update-Dashboard -Window $Window -Force -ScriptDir $ScriptDir
    
    $btnDashRefresh = $Window.FindName("btnDashRefresh")
    $txtDashFilter = $Window.FindName("txtDashFilter")
    $chkShowHidden = $Window.FindName("chkShowHidden")
    
    if ($null -ne $btnDashRefresh) {
        $btnDashRefresh.Add_Click({
                $win = $Window
                $filter = $win.FindName("txtDashFilter").Text
                $showHidden = [bool]($win.FindName("chkShowHidden").IsChecked)
                Update-Dashboard -Window $win -FilterText $filter -ShowHidden $showHidden -Force -ScriptDir $ScriptDir
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
                if ($s.SelectedIndex -eq 0) {
                    $win = $Window
                    $filter = $win.FindName("txtDashFilter").Text
                    $showHidden = [bool]($win.FindName("chkShowHidden").IsChecked)
                    Update-Dashboard -Window $win -FilterText $filter -ShowHidden $showHidden -ScriptDir $ScriptDir
                }
            }.GetNewClosure())
    }
}
