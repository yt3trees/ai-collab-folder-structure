# TabEditor.ps1 - Markdown editor tab: file tree, AvalonEdit editor, save/reload

# ---- File list definitions ----

# Returns ordered list of AI context file descriptors for a project
function Get-ProjectAIFiles {
    param([hashtable]$ProjectInfo)

    $aiCtx = $ProjectInfo.AiContextPath
    $projPath = $ProjectInfo.Path
    $files = [System.Collections.Generic.List[hashtable]]::new()

    $candidates = @(
        @{ Label = "current_focus.md"; Path = Join-Path $aiCtx "current_focus.md" }
        @{ Label = "project_summary.md"; Path = Join-Path $aiCtx "project_summary.md" }
        @{ Label = "file_map.md"; Path = Join-Path $aiCtx "file_map.md" }
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

    $logDir = Join-Path $ProjectInfo.AiContextPath "decision_log"
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
        "workspace_summary.md"
    )

    foreach ($name in $candidates) {
        $path = Join-Path $ctxDir $name
        if (Test-Path $path) {
            $files.Add(@{ Label = $name; Path = $path }) | Out-Null
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
    $fhDir = Join-Path $ProjectInfo.AiContextPath "focus_history"
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

    # Catppuccin Mocha theme styling
    $editor.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas, MS Gothic, Courier New")
    $editor.FontSize = 14
    $editor.Background = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#181825"))
    $editor.Foreground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#cdd6f4"))
    $editor.BorderThickness = New-Object System.Windows.Thickness(0)
    $editor.Padding = New-Object System.Windows.Thickness(12)
    $editor.ShowLineNumbers = $true
    $editor.WordWrap = $false
    $editor.HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $editor.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $editor.IsReadOnly = $true

    # Line number colors
    $editor.LineNumbersForeground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#45475a"))

    # Caret and selection colors
    $editor.TextArea.Caret.CaretBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#cdd6f4"))
    $editor.TextArea.SelectionBrush = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#45475a"))
    $editor.TextArea.SelectionForeground = $null  # Use syntax colors in selection

    # Current line highlight
    $editor.TextArea.TextView.CurrentLineBackground = [System.Windows.Media.SolidColorBrush](
        [System.Windows.Media.ColorConverter]::ConvertFromString("#11b4befe"))
    $editor.TextArea.TextView.CurrentLineBorder = New-Object System.Windows.Media.Pen(
        [System.Windows.Media.SolidColorBrush](
            [System.Windows.Media.ColorConverter]::ConvertFromString("#11b4befe")), 1)

    # Load Markdown syntax highlighting
    $xshdPath = Join-Path $ManagerDir "lib\Markdown.xshd"
    if (Test-Path $xshdPath) {
        try {
            $xshdStream = [System.IO.File]::OpenRead($xshdPath)
            $xmlReader = [System.Xml.XmlReader]::Create($xshdStream)
            $highlighting = [ICSharpCode.AvalonEdit.Highlighting.Xshd.HighlightingLoader]::Load(
                $xmlReader,
                [ICSharpCode.AvalonEdit.Highlighting.HighlightingManager]::Instance
            )
            $editor.SyntaxHighlighting = $highlighting
            $xmlReader.Close()
            $xshdStream.Close()
        }
        catch {
            # Silently fall back to no syntax highlighting
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
    $openFile = {
        param($s, $e)
        $selected = $s.SelectedItem
        if ($null -ne $selected -and $null -ne $selected.Tag) {
            $st = $Window.FindName("editorStatusText")
            Open-FileInEditor -FilePath $selected.Tag `
                -StatusText $st `
                -Window $Window
        }
    }
    $fileTree.Add_SelectedItemChanged($openFile)
    $workspaceTree.Add_SelectedItemChanged($openFile)

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
                $Window.FindName("editorStatusText").Text = "No file open"

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
                $st = $Window.FindName("editorStatusText")
                Open-FileInEditor -FilePath $proj.FocusFile `
                    -StatusText $st `
                    -Window $Window
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

            $statusText = $Window.FindName("editorStatusText")
            $fileName = [System.IO.Path]::GetFileName($currentFile)
            $dispText = if ($isDirty) { "$fileName *" } else { $fileName }
            $statusText.Text = $dispText

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
            }

            $statusText = $Window.FindName("editorStatusText")
            Open-FileInEditor -FilePath $currentFile `
                -StatusText $statusText `
                -Window $Window
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
                $statusText = $Window.FindName("editorStatusText")

                # Refresh tree and open new file
                Populate-FileTree `
                    -Tree            $Window.FindName("editorFileTree") `
                    -WorkspaceTree   $Window.FindName("editorWorkspaceTree") `
                    -ProjectInfo     $proj `
                    -WorkspaceRoot   $script:AppState.WorkspaceRoot `
                    -Window          $Window

                Open-FileInEditor -FilePath $newFile `
                    -StatusText $statusText `
                    -Window $Window
            }
        })

    # Fire initial SelectionChanged: goes from -1 to 0, which triggers the handler
    if ($editorProjectCombo.Items.Count -gt 0) {
        $editorProjectCombo.SelectedIndex = 0
    }
}
