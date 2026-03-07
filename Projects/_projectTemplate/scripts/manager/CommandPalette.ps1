# CommandPalette.ps1 - Ctrl+K command palette: quick access to all operations
# Provides VS Code-style command palette with incremental search

$script:PaletteState = @{
    Window    = $null
    Overlay   = $null
    Input     = $null
    List      = $null
    Commands  = @()
    Filtered  = @()
    IsVisible = $false
}

# ---- Command list builder ----

function Build-CommandList {
    param([System.Windows.Window]$Window)

    $commands = [System.Collections.Generic.List[hashtable]]::new()

    # --- Tab switch commands ---
    $tabDefs = @(
        @{ Index = 0; Label = "Dashboard" },
        @{ Index = 1; Label = "Editor" },
        @{ Index = 2; Label = "Setup" },
        @{ Index = 3; Label = "AI Context" },
        @{ Index = 4; Label = "Check" },
        @{ Index = 5; Label = "Archive" },
        @{ Index = 6; Label = "Convert" },
        @{ Index = 7; Label = "Asana Sync" },
        @{ Index = 8; Label = "Settings" }
    )

    foreach ($tab in $tabDefs) {
        $localIndex = $tab.Index
        $commands.Add(@{
                Label    = $tab.Label
                Category = "tab"
                Display  = "[Tab]  $($tab.Label)"
                Action   = {
                    param($w)
                    $tabMain = $w.FindName("tabMain")
                    $tabMain.SelectedIndex = $localIndex
                }.GetNewClosure()
            }) | Out-Null
    }

    # --- Project commands ---
    $projects = $script:AppState.Projects
    if ($null -eq $projects -or $projects.Count -eq 0) {
        $projects = Get-ProjectInfoList
    }

    foreach ($proj in $projects) {
        $localName = $proj.Name
        $localIsMini = ($proj.Tier -eq "mini")
        $localIsDomain = ($proj.Category -eq "domain")
        $localPath = $proj.Path

        # Build display suffix
        $suffix = if ($localIsDomain -and $localIsMini) { " [Domain][Mini]" }
        elseif ($localIsDomain) { " [Domain]" }
        elseif ($localIsMini) { " [Mini]" }
        else { "" }

        $displayName = "$localName$suffix"

        # > check ProjectName
        $commands.Add(@{
                Label    = "check $localName"
                Category = "project"
                Display  = "[>]  check $displayName"
                Action   = {
                    param($w)
                    $tabMain = $w.FindName("tabMain")
                    $tabMain.SelectedIndex = 4
                    $combo = $w.FindName("checkProjectCombo")
                    $combo.Text = $displayName
                    $w.FindName("checkMini").IsChecked = $localIsMini
                    $w.FindName("checkDomain").IsChecked = $localIsDomain
                }.GetNewClosure()
            }) | Out-Null

        # > edit ProjectName
        $commands.Add(@{
                Label    = "edit $localName"
                Category = "project"
                Display  = "[>]  edit $displayName"
                Action   = {
                    param($w)
                    $tabMain = $w.FindName("tabMain")
                    $tabMain.SelectedIndex = 1
                    $editorCombo = $w.FindName("editorProjectCombo")
                    for ($i = 0; $i -lt $editorCombo.Items.Count; $i++) {
                        if ($editorCombo.Items[$i].ToString() -eq $displayName) {
                            if ($editorCombo.SelectedIndex -eq $i) {
                                $editorCombo.SelectedIndex = -1
                            }
                            $editorCombo.SelectedIndex = $i
                            break
                        }
                    }
                }.GetNewClosure()
            }) | Out-Null

        # > term ProjectName
        $commands.Add(@{
                Label    = "term $localName"
                Category = "project"
                Display  = "[>]  term $displayName"
                Action   = {
                    param($w)
                    Open-TerminalAtPath -Path $localPath
                }.GetNewClosure()
            }) | Out-Null

        # > dir ProjectName
        $commands.Add(@{
                Label    = "dir $localName"
                Category = "project"
                Display  = "[>]  dir $displayName"
                Action   = {
                    param($w)
                    if (Test-Path $localPath) {
                        Start-Process explorer.exe -ArgumentList $localPath
                    }
                }.GetNewClosure()
            }) | Out-Null

        # @ ProjectName (editor shortcut)
        $commands.Add(@{
                Label    = "$localName"
                Category = "editor"
                Display  = "[@]  $displayName"
                Action   = {
                    param($w)
                    $tabMain = $w.FindName("tabMain")
                    $tabMain.SelectedIndex = 1
                    $editorCombo = $w.FindName("editorProjectCombo")
                    for ($i = 0; $i -lt $editorCombo.Items.Count; $i++) {
                        if ($editorCombo.Items[$i].ToString() -eq $displayName) {
                            if ($editorCombo.SelectedIndex -eq $i) {
                                $editorCombo.SelectedIndex = -1
                            }
                            $editorCombo.SelectedIndex = $i
                            break
                        }
                    }
                }.GetNewClosure()
            }) | Out-Null
    }

    return $commands
}

# ---- Filtering ----

function Update-PaletteFilter {
    $inputBox = $script:PaletteState.Input
    $listBox = $script:PaletteState.List
    if ($null -eq $inputBox -or $null -eq $listBox) { return }

    $rawText = $inputBox.Text.Trim()
    $listBox.Items.Clear()

    $filtered = [System.Collections.Generic.List[hashtable]]::new()

    # Detect category prefix: > for project commands, @ for editor commands
    $categoryFilter = $null
    $searchText = $rawText.ToLower()

    if ($rawText.StartsWith(">")) {
        $categoryFilter = "project"
        $searchText = $rawText.Substring(1).Trim().ToLower()
    }
    elseif ($rawText.StartsWith("@")) {
        $categoryFilter = "editor"
        $searchText = $rawText.Substring(1).Trim().ToLower()
    }

    if ([string]::IsNullOrEmpty($rawText)) {
        # Show all commands
        foreach ($cmd in $script:PaletteState.Commands) {
            $filtered.Add($cmd) | Out-Null
        }
    }
    elseif ($null -ne $categoryFilter -and [string]::IsNullOrEmpty($searchText)) {
        # Prefix only (just ">" or "@"): show all commands in that category
        foreach ($cmd in $script:PaletteState.Commands) {
            if ($cmd.Category -eq $categoryFilter) {
                $filtered.Add($cmd) | Out-Null
            }
        }
    }
    else {
        # Filter by tokens (AND search)
        $tokens = $searchText -split '\s+' | Where-Object { $_ -ne "" }

        foreach ($cmd in $script:PaletteState.Commands) {
            # If a category prefix is active, only search within that category
            if ($null -ne $categoryFilter -and $cmd.Category -ne $categoryFilter) { continue }

            $label = $cmd.Label.ToLower()
            $allMatch = $true
            foreach ($token in $tokens) {
                if ($label -notlike "*$token*") {
                    $allMatch = $false
                    break
                }
            }
            if ($allMatch) {
                $filtered.Add($cmd) | Out-Null
            }
        }

        # Sort: exact match > starts-with > contains
        $sorted = $filtered | Sort-Object {
            $label = $_.Label.ToLower()
            if ($label -eq $searchText) { return 0 }
            if ($label.StartsWith($searchText)) { return 1 }
            return 2
        }
        $filtered = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($item in $sorted) {
            $filtered.Add($item) | Out-Null
        }
    }

    $script:PaletteState.Filtered = $filtered

    foreach ($cmd in $filtered) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = $cmd.Display
        $item.Tag = $cmd
        $item.FontSize = 14
        $item.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas, Segoe UI")
        $item.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
        $item.Foreground = [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#cdd6f4"))
        $item.Cursor = [System.Windows.Input.Cursors]::Hand

        $listBox.Items.Add($item) | Out-Null
    }

    # Auto-select first item
    if ($listBox.Items.Count -gt 0) {
        $listBox.SelectedIndex = 0
    }
}

# ---- Show / Hide ----

function Show-CommandPalette {
    $overlay = $script:PaletteState.Overlay
    if ($null -eq $overlay) { return }

    # Rebuild commands each time (project list may have changed)
    $script:PaletteState.Commands = Build-CommandList -Window $script:PaletteState.Window

    $overlay.Visibility = [System.Windows.Visibility]::Visible
    $script:PaletteState.IsVisible = $true

    $script:PaletteState.Input.Text = ""
    Update-PaletteFilter

    # Focus the input
    $script:PaletteState.Input.Focus() | Out-Null
}

function Hide-CommandPalette {
    $overlay = $script:PaletteState.Overlay
    if ($null -eq $overlay) { return }

    $overlay.Visibility = [System.Windows.Visibility]::Collapsed
    $script:PaletteState.IsVisible = $false
}

function Test-CommandPaletteVisible {
    return $script:PaletteState.IsVisible
}

# ---- Execute ----

function Invoke-PaletteCommand {
    $listBox = $script:PaletteState.List
    if ($null -eq $listBox -or $null -eq $listBox.SelectedItem) { return }

    $selected = $listBox.SelectedItem
    $cmd = $selected.Tag

    Hide-CommandPalette

    if ($null -ne $cmd -and $null -ne $cmd.Action) {
        & $cmd.Action $script:PaletteState.Window
    }
}

# ---- Initialize ----

function Initialize-CommandPalette {
    param([System.Windows.Window]$Window)

    $script:PaletteState.Window = $Window
    $script:PaletteState.Overlay = $Window.FindName("cmdPaletteOverlay")
    $script:PaletteState.Input = $Window.FindName("cmdPaletteInput")
    $script:PaletteState.List = $Window.FindName("cmdPaletteList")

    if ($null -eq $script:PaletteState.Overlay) { return }

    # Text changed -> filter
    $script:PaletteState.Input.Add_TextChanged({
            Update-PaletteFilter
        })

    # Keyboard navigation in the input box
    $script:PaletteState.Input.Add_PreviewKeyDown({
            param($s, $e)

            if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
                Hide-CommandPalette
                $e.Handled = $true
                return
            }

            if ($e.Key -eq [System.Windows.Input.Key]::Return) {
                Invoke-PaletteCommand
                $e.Handled = $true
                return
            }

            $listBox = $script:PaletteState.List
            if ($null -eq $listBox -or $listBox.Items.Count -eq 0) { return }

            if ($e.Key -eq [System.Windows.Input.Key]::Down) {
                $idx = $listBox.SelectedIndex + 1
                if ($idx -lt $listBox.Items.Count) {
                    $listBox.SelectedIndex = $idx
                    $listBox.ScrollIntoView($listBox.SelectedItem)
                }
                $e.Handled = $true
            }
            elseif ($e.Key -eq [System.Windows.Input.Key]::Up) {
                $idx = $listBox.SelectedIndex - 1
                if ($idx -ge 0) {
                    $listBox.SelectedIndex = $idx
                    $listBox.ScrollIntoView($listBox.SelectedItem)
                }
                $e.Handled = $true
            }
        })

    # Double-click on list item
    $script:PaletteState.List.Add_MouseDoubleClick({
            Invoke-PaletteCommand
        })

    # Click on overlay background to close
    $script:PaletteState.Overlay.Add_MouseLeftButtonDown({
            param($s, $e)
            # Only close if clicking directly on the overlay (not the inner panel)
            if ($e.OriginalSource -eq $s) {
                Hide-CommandPalette
                $e.Handled = $true
            }
        })
}
