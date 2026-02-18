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

# ---- Build one project card ----

function New-ProjectCard {
    param(
        [hashtable]$Info,
        [System.Windows.Window]$Window,
        [string]$ScriptDir
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

    $stack = New-Object System.Windows.Controls.StackPanel

    # --- Title row ---
    $titleRow = New-Object System.Windows.Controls.StackPanel
    $titleRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $titleRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = $Info.Name
    $titleBlock.FontSize = 14
    $titleBlock.FontWeight = [System.Windows.FontWeights]::SemiBold
    $titleBlock.Foreground = New-ColorBrush "#cba6f7"

    $tierBadge = New-Object System.Windows.Controls.TextBlock
    $badgeText = if ($Info.Tier -eq "mini") { " [M]" } else { " [F]" }
    $tierBadge.Text = $badgeText
    $tierBadge.FontSize = 11
    $tierBadge.Foreground = New-ColorBrush "#a6adc8"
    $tierBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $titleRow.Children.Add($titleBlock) | Out-Null
    $titleRow.Children.Add($tierBadge)  | Out-Null
    $stack.Children.Add($titleRow)      | Out-Null

    # --- Focus freshness ---
    $focusText = if ($null -eq $Info.FocusAge) {
        "Focus: --"
    }
    elseif ($Info.FocusAge -eq 0) {
        "Focus: today"
    }
    else {
        "Focus: $($Info.FocusAge)d ago"
    }
    $focusBlock = New-Object System.Windows.Controls.TextBlock
    $focusBlock.Text = $focusText
    $focusBlock.FontSize = 12
    $focusBlock.Foreground = New-ColorBrush (Get-FreshnessColor -Days $Info.FocusAge -WarnAt 7 -AlertAt 14)
    $focusBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
    $stack.Children.Add($focusBlock) | Out-Null

    # --- Summary freshness ---
    $summText = if ($null -eq $Info.SummaryAge) {
        "Summary: --"
    }
    elseif ($Info.SummaryAge -eq 0) {
        "Summary: today"
    }
    else {
        "Summary: $($Info.SummaryAge)d ago"
    }
    $summBlock = New-Object System.Windows.Controls.TextBlock
    $summBlock.Text = $summText
    $summBlock.FontSize = 12
    $summBlock.Foreground = New-ColorBrush (Get-FreshnessColor -Days $Info.SummaryAge -WarnAt 14 -AlertAt 30)
    $summBlock.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
    $stack.Children.Add($summBlock) | Out-Null

    # --- Junction status ---
    $junctionColor = if ($Info.JunctionShared -eq "OK" -and $Info.JunctionObsidian -eq "OK") {
        "#a6e3a1"
    }
    elseif ($Info.JunctionShared -eq "Missing" -or $Info.JunctionObsidian -eq "Missing") {
        "#f38ba8"
    }
    else {
        "#fab387"
    }
    $junctionBlock = New-Object System.Windows.Controls.TextBlock
    $junctionBlock.Text = "Junctions: $($Info.JunctionShared) / $($Info.JunctionObsidian)"
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

    # --- Action buttons ---
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnPanel.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)

    # Capture values for closures
    $projName = $Info.Name
    $projTier = $Info.Tier
    $isMini = ($Info.Tier -eq "mini")

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

    $btnCheck.Add_Click({
            $tabMain = $Window.FindName("tabMain")
            $tabMain.SelectedIndex = 4  # Check tab

            $checkCombo = $Window.FindName("checkProjectCombo")
            $checkCombo.Text = $projName

            $checkMiniBox = $Window.FindName("checkMini")
            $checkMiniBox.IsChecked = $isMini
        })

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

    $btnEdit.Add_Click({
            $tabMain = $Window.FindName("tabMain")
            $tabMain.SelectedIndex = 1  # Editor tab

            $editorCombo = $Window.FindName("editorProjectCombo")
            # Select matching item
            for ($i = 0; $i -lt $editorCombo.Items.Count; $i++) {
                if ($editorCombo.Items[$i] -eq $projName) {
                    $editorCombo.SelectedIndex = $i
                    break
                }
            }
        })

    $btnPanel.Children.Add($btnCheck) | Out-Null
    $btnPanel.Children.Add($btnEdit)  | Out-Null
    $stack.Children.Add($btnPanel)    | Out-Null

    $card.Child = $stack
    return $card
}

# ---- Refresh the dashboard ----

function Update-Dashboard {
    param(
        [System.Windows.Window]$Window,
        [string]$FilterText = ""
    )

    $cardsPanel = $Window.FindName("dashboardCards")
    $cardsPanel.Children.Clear()

    $projects = Get-ProjectInfoList

    $filter = $FilterText.Trim().ToLower()

    foreach ($proj in $projects) {
        if ($filter -ne "" -and $proj.Name.ToLower() -notlike "*$filter*") {
            continue
        }
        $card = New-ProjectCard -Info $proj -Window $Window
        $cardsPanel.Children.Add($card) | Out-Null
    }

    if ($cardsPanel.Children.Count -eq 0) {
        $emptyBlock = New-Object System.Windows.Controls.TextBlock
        $emptyBlock.Text = "No projects found."
        $emptyBlock.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#6c7086")
        )
        $emptyBlock.FontSize = 13
        $emptyBlock.Margin = New-Object System.Windows.Thickness(8)
        $cardsPanel.Children.Add($emptyBlock) | Out-Null
    }
}

# ---- Initialize ----

function Initialize-TabDashboard {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    $btnDashRefresh = $Window.FindName("btnDashRefresh")
    $txtDashFilter = $Window.FindName("txtDashFilter")
    $tabMain = $Window.FindName("tabMain")

    # Initial load
    Update-Dashboard -Window $Window

    # Refresh button
    $btnDashRefresh.Add_Click({
            $filter = $Window.FindName("txtDashFilter")
            Update-Dashboard -Window $Window -FilterText $filter.Text
        })

    # Live filter
    $txtDashFilter.Add_TextChanged({
            $filter = $Window.FindName("txtDashFilter")
            Update-Dashboard -Window $Window -FilterText $filter.Text
        })

    # Reload dashboard when switching back to the Dashboard tab
    $tabMain.Add_SelectionChanged({
            $tab = $Window.FindName("tabMain")
            if ($tab.SelectedIndex -eq 0) {
                $filter = $Window.FindName("txtDashFilter")
                Update-Dashboard -Window $Window -FilterText $filter.Text
            }
        })
}
