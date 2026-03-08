# TabEditor.ps1 - Markdown editor tab: file tree, AvalonEdit editor, save/reload

# ---- File list definitions ----

# Returns ordered list of AI context file descriptors for a project
function Get-ProjectAIFiles {
    param([hashtable]$ProjectInfo)

    $aiCtx = $ProjectInfo.AiContextPath
    $aiCtxContent = Join-Path $aiCtx "context"
    $projPath = $ProjectInfo.Path
    $files = [System.Collections.Generic.List[hashtable]]::new()

    $candidates = @(
        @{ Label = "current_focus.md"; Path = Join-Path $aiCtxContent "current_focus.md" }
        @{ Label = "project_summary.md"; Path = Join-Path $aiCtxContent "project_summary.md" }
        @{ Label = "tensions.md"; Path = Join-Path $aiCtxContent "tensions.md" }
        @{ Label = "file_map.md"; Path = Join-Path $aiCtxContent "file_map.md" }
        @{ Label = "AGENTS.md"; Path = Join-Path $projPath "AGENTS.md" }
        @{ Label = "CLAUDE.md"; Path = Join-Path $projPath "CLAUDE.md" }
    )

    foreach ($c in $candidates) {
        if (Test-Path $c.Path) {
            $files.Add($c) | Out-Null
        }
    }

    return $files
}

# Returns decision log files for a project (excluding TEMPLATE.md)
function Get-DecisionLogFiles {
    param([hashtable]$ProjectInfo)

    $logDir = Join-Path $ProjectInfo.AiContextPath "context\decision_log"
    $files = [System.Collections.Generic.List[hashtable]]::new()

    if (Test-Path $logDir) {
        # Include TEMPLATE.md first
        $tmpl = Join-Path $logDir "TEMPLATE.md"
        if (Test-Path $tmpl) {
            $files.Add(@{ Label = "TEMPLATE.md"; Path = $tmpl }) | Out-Null
        }

        # Then sorted log files, newest first
        $mdFiles = Get-ChildItem $logDir -Filter "*.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "TEMPLATE.md" } |
        Sort-Object LastWriteTime -Descending
        foreach ($f in $mdFiles) {
            $files.Add(@{ Label = $f.Name; Path = $f.FullName }) | Out-Null
        }
    }

    return $files
}

# Workspace-level files from .context/
function Get-WorkspaceAIFiles {
    param([string]$WorkspaceRoot)

    $ctxDir = Join-Path $WorkspaceRoot ".context"
    $files = [System.Collections.Generic.List[hashtable]]::new()

    $candidates = @(
        "active_projects.md"
        "current_focus.md"
        "tensions.md"
        "workspace_summary.md"
    )

    foreach ($name in $candidates) {
        $path = Join-Path $ctxDir $name
        if (Test-Path $path) {
            $files.Add(@{ Label = $name; Path = $path }) | Out-Null
        }
    }

    # asana-tasks-view.md at workspace root
    $asanaView = Join-Path $WorkspaceRoot "asana-tasks-view.md"
    if (Test-Path $asanaView) {
        $files.Add(@{ Label = "asana-tasks-view.md"; Path = $asanaView }) | Out-Null
    }

    return $files
}

# Asana task files for a project
function Get-AsanaFiles {
    param([hashtable]$ProjectInfo)

    $obsidianNotesPath = Join-Path $ProjectInfo.AiContextPath "obsidian_notes"
    $files = [System.Collections.Generic.List[hashtable]]::new()

    $candidates = @(
        @{ Label = "asana-tasks.md"; Path = Join-Path $obsidianNotesPath "asana-tasks.md" }
    )

    foreach ($c in $candidates) {
        if (Test-Path $c.Path) {
            $files.Add($c) | Out-Null
        }
    }

    return $files
}

# ---- Build TreeView ----

function New-TreeItem {
    param([string]$Label, [string]$FilePath = $null)

    $item = New-Object System.Windows.Controls.TreeViewItem
    $item.Header = $Label
    if ($null -ne $FilePath) {
        $item.Tag = $FilePath
    }
    return $item
}

# Load the context menu functions
. (Join-Path $PSScriptRoot "TabEditorContextMenu.ps1")



function Populate-FileTree {
    param(
        [System.Windows.Controls.TreeView]$Tree,
        [System.Windows.Controls.TreeView]$WorkspaceTree,
        [hashtable]$ProjectInfo,
        [string]$WorkspaceRoot,
        [System.Windows.Window]$Window
    )

    $Tree.Items.Clear()
    $WorkspaceTree.Items.Clear()

    # --- Project: AI Context folder ---
    $aiFiles = Get-ProjectAIFiles -ProjectInfo $ProjectInfo
    $dlFiles = Get-DecisionLogFiles -ProjectInfo $ProjectInfo

    if ($aiFiles.Count -gt 0) {
        $aiFolder = New-TreeItem -Label "_ai-context"
        $aiFolder.IsExpanded = $true

        foreach ($f in $aiFiles) {
            $child = New-TreeItem -Label $f.Label -FilePath $f.Path
            Add-ContextMenuToTreeItem -Item $child -Window $Window
            $aiFolder.Items.Add($child) | Out-Null
        }
        $Tree.Items.Add($aiFolder) | Out-Null
    }

    if ($dlFiles.Count -gt 0) {
        $dlFolder = New-TreeItem -Label "decision_log"
        $dlFolder.IsExpanded = $false

        foreach ($f in $dlFiles) {
            $child = New-TreeItem -Label $f.Label -FilePath $f.Path
            Add-ContextMenuToTreeItem -Item $child -Window $Window
            $dlFolder.Items.Add($child) | Out-Null
        }
        $Tree.Items.Add($dlFolder) | Out-Null
    }

    # --- Focus History ---
    $fhDir = Join-Path $ProjectInfo.AiContextPath "context\focus_history"
    if (Test-Path $fhDir) {
        $fhFiles = Get-ChildItem $fhDir -Filter "*.md" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
        if ($fhFiles.Count -gt 0) {
            $fhFolder = New-TreeItem -Label "focus_history"
            $fhFolder.IsExpanded = $false

            foreach ($f in $fhFiles) {
                $child = New-TreeItem -Label $f.Name -FilePath $f.FullName
                Add-ContextMenuToTreeItem -Item $child -Window $Window
                $fhFolder.Items.Add($child) | Out-Null
            }
            $Tree.Items.Add($fhFolder) | Out-Null
        }
    }

    # --- Asana Tasks ---
    $asanaFiles = Get-AsanaFiles -ProjectInfo $ProjectInfo
    if ($asanaFiles.Count -gt 0) {
        $asanaFolder = New-TreeItem -Label "asana"
        $asanaFolder.IsExpanded = $true

        foreach ($f in $asanaFiles) {
            $child = New-TreeItem -Label $f.Label -FilePath $f.Path
            Add-ContextMenuToTreeItem -Item $child -Window $Window
            $asanaFolder.Items.Add($child) | Out-Null
        }
        $Tree.Items.Add($asanaFolder) | Out-Null
    }

    # --- Workspace: .context/ files ---
    $wsFiles = Get-WorkspaceAIFiles -WorkspaceRoot $WorkspaceRoot

    if ($wsFiles.Count -gt 0) {
        $wsFolder = New-TreeItem -Label ".context"
        $wsFolder.IsExpanded = $true

        foreach ($f in $wsFiles) {
            $child = New-TreeItem -Label $f.Label -FilePath $f.Path
            Add-ContextMenuToTreeItem -Item $child -Window $Window
            $wsFolder.Items.Add($child) | Out-Null
        }
        $WorkspaceTree.Items.Add($wsFolder) | Out-Null
    }

    # --- Workspace: briefings/ files ---
    $briefingsDir1 = Join-Path $WorkspaceRoot "_ai-workspace\briefings"
    $briefingsDir2 = Join-Path $WorkspaceRoot "_briefings"
    $bDir = if (Test-Path $briefingsDir1) { $briefingsDir1 } elseif (Test-Path $briefingsDir2) { $briefingsDir2 } else { $null }

    if ($null -ne $bDir) {
        $bFiles = Get-ChildItem $bDir -Filter "*.md" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
            
        if ($bFiles.Count -gt 0) {
            $bFolder = New-TreeItem -Label "briefings"
            $bFolder.IsExpanded = $true
            
            foreach ($f in $bFiles) {
                $child = New-TreeItem -Label $f.Name -FilePath $f.FullName
                Add-ContextMenuToTreeItem -Item $child -Window $Window
                $bFolder.Items.Add($child) | Out-Null
            }
            $WorkspaceTree.Items.Add($bFolder) | Out-Null
        }
    }
}

# ---- Helper: resolve selected project from combo text ----

function Get-SelectedEditorProject {
    param([string]$ComboText)

    if ([string]::IsNullOrEmpty($ComboText)) { return $null }
    $params = Get-ProjectParams -ComboText $ComboText -MiniChecked $false
    $name = $params.Name
    # Use case-insensitive comparison for project name matching
    $proj = $script:AppState.Projects | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    return $proj
}

# ---- Create AvalonEdit TextEditor ----

function New-AvalonEditEditor {
    param([string]$ManagerDir)

    $editor = New-Object ICSharpCode.AvalonEdit.TextEditor
    $c = Get-ThemeColors -ThemeName $script:AppState.Theme

    $editor.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas, MS Gothic, Courier New")
    $editor.FontSize = 14
    $editor.Background = New-ColorBrush $c.Mantle
    $editor.Foreground = New-ColorBrush $c.Text
    $editor.BorderThickness = New-Object System.Windows.Thickness(0)
    $editor.Padding = New-Object System.Windows.Thickness(12)
    $editor.ShowLineNumbers = $true
    $editor.WordWrap = $false
    $editor.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $editor.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $editor.IsReadOnly = $true

    # Line number colors
    $editor.LineNumbersForeground = New-ColorBrush $c.Surface2

    # Caret and selection colors
    $editor.TextArea.Caret.CaretBrush = New-ColorBrush $c.Text
    $editor.TextArea.SelectionBrush = New-ColorBrush $c.Surface1
    $editor.TextArea.SelectionForeground = $null  # Use syntax colors in selection

    # Remove built-in LinkElementGenerator
    $generators = $editor.TextArea.TextView.ElementGenerators
    $toRemove = @($generators | Where-Object { $_.GetType().Name -eq "LinkElementGenerator" })
    foreach ($g in $toRemove) { $generators.Remove($g) | Out-Null }

    # Current line highlight
    $editor.TextArea.TextView.CurrentLineBackground = New-ColorBrush ("#11" + $c.Lavender.TrimStart('#'))
    $editor.TextArea.TextView.CurrentLineBorder = New-Object System.Windows.Media.Pen(
        New-ColorBrush ("#11" + $c.Lavender.TrimStart('#')), 1)

    # Load Markdown syntax highlighting
    $xshdPath = Join-Path $ManagerDir "lib\Markdown.xshd"
    if (Test-Path $xshdPath) {
        try {
            $xshdContent = Get-Content $xshdPath -Raw
            
            # Apply dynamic replacements based on theme
            if ($script:AppState.Theme -eq "GitHub") {
                $replacements = @{
                    "#cba6f7" = $c.Blue
                    "#f5c2e7" = $c.Mauve
                    "#a6e3a1" = $c.Green
                    "#9399b2" = $c.Subtext0  # Comment / BlockQuote
                    "#74c7ec" = $c.Sapphire
                    "#94e2d5" = $c.Teal
                    "#f9e2af" = $c.Yellow
                    "#6c7086" = $c.Overlay0
                    "#313244" = $c.Surface1
                }
                foreach ($oldHex in $replacements.Keys) {
                    $xshdContent = $xshdContent.Replace($oldHex, $replacements[$oldHex])
                }
            }

            $sr = New-Object System.IO.StringReader($xshdContent)
            $xmlReader = [System.Xml.XmlReader]::Create($sr)
            $highlighting = [ICSharpCode.AvalonEdit.Highlighting.Xshd.HighlightingLoader]::Load(
                $xmlReader,
                [ICSharpCode.AvalonEdit.Highlighting.HighlightingManager]::Instance
            )
            $editor.SyntaxHighlighting = $highlighting
            $xmlReader.Close()
            $sr.Close()
        }
        catch {
            Write-Error "Failed to load syntax highlighting: $($_.Exception.Message)"
        }
    }

    return $editor
}

# ---- Initialize Editor Tab ----

function Initialize-TabEditor {
    param([System.Windows.Window]$Window)

    $editorProjectCombo = $Window.FindName("editorProjectCombo")

    # Populate project dropdown (SelectedIndex intentionally left at -1 until handler is attached)
    $nameList = Get-ProjectNameList
    foreach ($n in $nameList) {
        $editorProjectCombo.Items.Add($n) | Out-Null
    }

    # Create AvalonEdit TextEditor and add to host
    $managerDir = Split-Path $PSScriptRoot -Parent
    # PSScriptRoot here is the manager/ dir since TabEditor.ps1 is dot-sourced from there
    $managerDir = $PSScriptRoot
    $editor = New-AvalonEditEditor -ManagerDir $managerDir
    $editorHost = $Window.FindName("editorHost")
    $editorHost.Content = $editor

    # Store reference in AppState
    $script:AppState.EditorControl = $editor
    $script:AppState.EditorState.SuppressChangeEvent = $false

    # Register tree file-open handlers ONCE here (prevents accumulation on project switch)
    $fileTree = $Window.FindName("editorFileTree")
    $workspaceTree = $Window.FindName("editorWorkspaceTree")
    $script:_treeSelecting = $false
    $fileTree.Add_SelectedItemChanged({
            param($s, $e)
            if ($script:_treeSelecting) { return }
            $script:_treeSelecting = $true
            $wt = $Window.FindName("editorWorkspaceTree")
            if ($null -ne $wt.SelectedItem) { $wt.SelectedItem.IsSelected = $false }
            $selected = $s.SelectedItem
            if ($null -ne $selected -and $null -ne $selected.Tag) {
                Open-FileInEditor -FilePath $selected.Tag -Window $Window
            }
            $script:_treeSelecting = $false
        })
    $workspaceTree.Add_SelectedItemChanged({
            param($s, $e)
            if ($script:_treeSelecting) { return }
            $script:_treeSelecting = $true
            $ft = $Window.FindName("editorFileTree")
            if ($null -ne $ft.SelectedItem) { $ft.SelectedItem.IsSelected = $false }
            $selected = $s.SelectedItem
            if ($null -ne $selected -and $null -ne $selected.Tag) {
                Open-FileInEditor -FilePath $selected.Tag -Window $Window
            }
            $script:_treeSelecting = $false
        })

    # When project changes, reload file tree
    $editorProjectCombo.Add_SelectionChanged({
            # Close current file before switching
            $state = $script:AppState.EditorState
            if (-not [string]::IsNullOrEmpty($state.CurrentFile)) {
                if ($state.IsDirty) {
                    $fName = [System.IO.Path]::GetFileName($state.CurrentFile)
                    $res = [System.Windows.MessageBox]::Show(
                        "Save changes to '$fName' before switching projects?",
                        "Unsaved Changes",
                        [System.Windows.MessageBoxButton]::YesNoCancel,
                        [System.Windows.MessageBoxImage]::Warning
                    )

                    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
                        Save-EditorFile -Window $Window
                        if ($script:AppState.EditorState.IsDirty) { return } # Save failed
                    }
                    elseif ($res -eq [System.Windows.MessageBoxResult]::Cancel) {
                        return
                    }
                }

                # Clear editor UI (suppress change event while clearing)
                $ed = $script:AppState.EditorControl
                $script:AppState.EditorState.SuppressChangeEvent = $true
                $ed.Text = ""
                $ed.IsReadOnly = $true
                $script:AppState.EditorState.SuppressChangeEvent = $false
                $btnSave = $Window.FindName("btnEditorSave")
                if ($null -ne $btnSave) { $btnSave.IsEnabled = $false }

                $btnReload = $Window.FindName("btnEditorReload")
                if ($null -ne $btnReload) { $btnReload.IsEnabled = $false }

                $state.CurrentFile = ""
                $state.OriginalContent = ""
                $state.IsDirty = $false

                Update-StatusBar -Window $Window -File "" -Encoding "" -Dirty $false
            }

            $combo = $Window.FindName("editorProjectCombo")
            # Use SelectedItem (not Text) for reliable value on non-editable ComboBox
            $selText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
            $proj = Get-SelectedEditorProject -ComboText $selText
            if ($null -eq $proj) { return }

            $script:AppState.SelectedProject = $proj
            Update-StatusBar -Window $Window -Project $proj.Name

            $ft = $Window.FindName("editorFileTree")
            $wt = $Window.FindName("editorWorkspaceTree")

            # Populate file tree
            Populate-FileTree `
                -Tree            $ft `
                -WorkspaceTree   $wt `
                -ProjectInfo     $proj `
                -WorkspaceRoot   $script:AppState.WorkspaceRoot `
                -Window          $Window

            # Auto-open current_focus.md if available
            if ($null -ne $proj.FocusFile) {
                Open-FileInEditor -FilePath $proj.FocusFile -Window $Window
            }
        })

    # Track dirty state on text change (AvalonEdit Document.Changed event)
    $editor.Document.Add_Changed({
            if ($script:AppState.EditorState.SuppressChangeEvent) { return }

            $currentFile = $script:AppState.EditorState.CurrentFile
            if ([string]::IsNullOrEmpty($currentFile)) { return }

            $ed = $script:AppState.EditorControl
            $isDirty = ($ed.Text -ne $script:AppState.EditorState.OriginalContent)
            $script:AppState.EditorState.IsDirty = $isDirty

            Update-StatusBar -Window $Window `
                -Dirty $isDirty
        })

    # Ctrl+S shortcut on editor
    $editor.Add_KeyDown({
            if ($_.Key -eq [System.Windows.Input.Key]::S -and
                [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl)) {
                Save-EditorFile -Window $Window
                $_.Handled = $true
            }
        })

    # Shift+Mouse wheel for horizontal scrolling
    $editor.Add_PreviewMouseWheel({
            if ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or
                [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)) {
                # Walk up the visual tree to find the ScrollViewer
                $sv = $null
                $current = $script:AppState.EditorControl.TextArea
                while ($null -ne $current) {
                    if ($current -is [System.Windows.Controls.ScrollViewer]) {
                        $sv = $current
                        break
                    }
                    $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
                }
                if ($null -ne $sv) {
                    $offset = $sv.HorizontalOffset - $_.Delta
                    $sv.ScrollToHorizontalOffset($offset)
                }
                $_.Handled = $true
            }
        })

    # Save button
    $Window.FindName("btnEditorSave").Add_Click({
            Save-EditorFile -Window $Window
            # Refresh tree so focus_history snapshots appear immediately after save
            $proj = $script:AppState.SelectedProject
            if ($null -ne $proj) {
                Populate-FileTree `
                    -Tree          $Window.FindName("editorFileTree") `
                    -WorkspaceTree $Window.FindName("editorWorkspaceTree") `
                    -ProjectInfo   $proj `
                    -WorkspaceRoot $script:AppState.WorkspaceRoot `
                    -Window        $Window
            }
        })

    # Reload button
    $Window.FindName("btnEditorReload").Add_Click({
            $currentFile = $script:AppState.EditorState.CurrentFile
            if ([string]::IsNullOrEmpty($currentFile)) { return }

            if ($script:AppState.EditorState.IsDirty) {
                $result = [System.Windows.MessageBox]::Show(
                    "Reload and discard unsaved changes?",
                    "Reload",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question
                )
                if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
                # Clear dirty flag so Open-FileInEditor skips its own IsDirty prompt
                $script:AppState.EditorState.IsDirty = $false
            }

            Open-FileInEditor -FilePath $currentFile -Window $Window

            # Refresh tree to reflect any filesystem changes
            $proj = $script:AppState.SelectedProject
            if ($null -ne $proj) {
                Populate-FileTree `
                    -Tree          $Window.FindName("editorFileTree") `
                    -WorkspaceTree $Window.FindName("editorWorkspaceTree") `
                    -ProjectInfo   $proj `
                    -WorkspaceRoot $script:AppState.WorkspaceRoot `
                    -Window        $Window
            }
        })

    # Term button
    $btnEditorTerm = $Window.FindName("btnEditorTerm")

    $btnEditorTerm.Add_Click({
            $proj = $script:AppState.SelectedProject
            if ($null -ne $proj) { Open-TerminalAtPath -Path $proj.Path }
        })

    $btnEditorTerm.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true
            $proj = $script:AppState.SelectedProject
            if ($null -eq $proj) { return }
            $termPath = $proj.Path

            if ($null -ne $script:currentTermPopup) {
                $script:currentTermPopup.IsOpen = $false
                $script:currentTermPopup = $null
            }

            $popup = New-Object System.Windows.Controls.Primitives.Popup
            $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
            $popup.PlacementTarget = $sender
            $popup.StaysOpen = $false
            $popup.AllowsTransparency = $true

            $border = New-Object System.Windows.Controls.Border
            $border.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#313244"))
            $border.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#45475a"))
            $border.BorderThickness = New-Object System.Windows.Thickness(1)
            $border.Padding = New-Object System.Windows.Thickness(2)

            $menuStack = New-Object System.Windows.Controls.StackPanel

            foreach ($agentDef in @(
                    @{ Label = "Claude"; Cmd = "claude" },
                    @{ Label = "Gemini"; Cmd = "gemini" },
                    @{ Label = "Codex"; Cmd = "codex" }
                )) {
                $menuItem = New-Object System.Windows.Controls.TextBlock
                $menuItem.Text = $agentDef.Label
                $menuItem.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#cdd6f4"))
                $menuItem.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#313244"))
                $menuItem.Padding = New-Object System.Windows.Thickness(12, 5, 12, 5)
                $menuItem.Cursor = [System.Windows.Input.Cursors]::Hand
                $menuItem.Tag = @{ Path = $termPath; Cmd = $agentDef.Cmd; Popup = $popup }
                $menuItem.Add_MouseEnter({ $this.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#45475a")) })
                $menuItem.Add_MouseLeave({ $this.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#313244")) })
                $menuItem.Add_MouseLeftButtonDown({
                        param($sender, $e)
                        $e.Handled = $true
                        $d = $sender.Tag
                        $d.Popup.IsOpen = $false
                        $script:currentTermPopup = $null
                        Open-AgentAtPath -Path $d.Path -Agent $d.Cmd
                    })
                $menuStack.Children.Add($menuItem) | Out-Null
            }

            $border.Child = $menuStack
            $popup.Child = $border
            $script:currentTermPopup = $popup
            $popup.IsOpen = $true
        })

    # Resume button
    $Window.FindName("btnEditorResume").Add_Click({
            $proj = $script:AppState.SelectedProject
            if ($null -eq $proj) { return }
            $feature = Show-ResumeDialog -ProjName $proj.Name -Owner $Window
            if (-not [string]::IsNullOrWhiteSpace($feature)) {
                Invoke-ResumeWork -ProjPath $proj.Path -FeatureName $feature
            }
        })

    # New Decision Log button
    $Window.FindName("btnNewDecisionLog").Add_Click({
            $combo = $Window.FindName("editorProjectCombo")
            $selText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
            $proj = Get-SelectedEditorProject -ComboText $selText
            if ($null -eq $proj) {
                [System.Windows.MessageBox]::Show(
                    "Please select a project first.",
                    "No Project Selected",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null
                return
            }

            $newFile = New-DecisionLog -AiContextPath $proj.AiContextPath -Window $Window
            if ($null -ne $newFile) {
                # Refresh tree and open new file
                Populate-FileTree `
                    -Tree            $Window.FindName("editorFileTree") `
                    -WorkspaceTree   $Window.FindName("editorWorkspaceTree") `
                    -ProjectInfo     $proj `
                    -WorkspaceRoot   $script:AppState.WorkspaceRoot `
                    -Window          $Window

                Open-FileInEditor -FilePath $newFile -Window $Window
            }
        })

    # Fire initial SelectionChanged: goes from -1 to 0, which triggers the handler
    if ($editorProjectCombo.Items.Count -gt 0) {
        $editorProjectCombo.SelectedIndex = 0
    }
}
