# TabEditor.ps1 - Markdown editor tab: file tree, editor, save/reload

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
            $aiFolder.Items.Add($child) | Out-Null
        }
        $Tree.Items.Add($aiFolder) | Out-Null
    }

    if ($dlFiles.Count -gt 0) {
        $dlFolder = New-TreeItem -Label "decision_log"
        $dlFolder.IsExpanded = $false

        foreach ($f in $dlFiles) {
            $child = New-TreeItem -Label $f.Label -FilePath $f.Path
            $dlFolder.Items.Add($child) | Out-Null
        }
        $Tree.Items.Add($dlFolder) | Out-Null
    }

    # --- Workspace: .context/ files ---
    $wsFiles = Get-WorkspaceAIFiles -WorkspaceRoot $WorkspaceRoot

    if ($wsFiles.Count -gt 0) {
        $wsFolder = New-TreeItem -Label ".context"
        $wsFolder.IsExpanded = $true

        foreach ($f in $wsFiles) {
            $child = New-TreeItem -Label $f.Label -FilePath $f.Path
            $wsFolder.Items.Add($child) | Out-Null
        }
        $WorkspaceTree.Items.Add($wsFolder) | Out-Null
    }

    # Attach click handlers to both trees
    $openFile = {
        param($s, $e)
        $selected = $s.SelectedItem
        if ($null -ne $selected -and $null -ne $selected.Tag) {
            $eb = $Window.FindName("editorTextBox")
            $st = $Window.FindName("editorStatusText")
            Open-FileInEditor -FilePath $selected.Tag `
                -EditorBox $eb `
                -StatusText $st `
                -Window $Window
        }
    }

    $Tree.Add_SelectedItemChanged($openFile)
    $WorkspaceTree.Add_SelectedItemChanged($openFile)
}

# ---- Helper: resolve selected project from combo text ----

function Get-SelectedEditorProject {
    param([string]$ComboText)

    if ([string]::IsNullOrEmpty($ComboText)) { return $null }
    $params = Get-ProjectParams -ComboText $ComboText -MiniChecked $false
    $name = $params.Name
    $proj = $script:AppState.Projects | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    return $proj
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

    # When project changes, reload file tree
    $editorProjectCombo.Add_SelectionChanged({
            $combo = $Window.FindName("editorProjectCombo")
            $proj = Get-SelectedEditorProject -ComboText $combo.Text
            if ($null -eq $proj) { return }

            $script:AppState.SelectedProject = $proj
            Update-StatusBar -Window $Window -Project $proj.Name

            $fileTree = $Window.FindName("editorFileTree")
            $workspaceTree = $Window.FindName("editorWorkspaceTree")

            Populate-FileTree `
                -Tree            $fileTree `
                -WorkspaceTree   $workspaceTree `
                -ProjectInfo     $proj `
                -WorkspaceRoot   $script:AppState.WorkspaceRoot `
                -Window          $Window
        })

    # Track dirty state on text change
    $Window.FindName("editorTextBox").Add_TextChanged({
            $editorBox = $Window.FindName("editorTextBox")
            $statusText = $Window.FindName("editorStatusText")

            if (-not $editorBox.IsEnabled) { return }
            $currentFile = $script:AppState.EditorState.CurrentFile
            if ([string]::IsNullOrEmpty($currentFile)) { return }

            $isDirty = ($editorBox.Text -ne $script:AppState.EditorState.OriginalContent)
            $script:AppState.EditorState.IsDirty = $isDirty

            $fileName = [System.IO.Path]::GetFileName($currentFile)
            $dispText = if ($isDirty) { "$fileName *" } else { $fileName }
            $statusText.Text = $dispText

            Update-StatusBar -Window $Window `
                -Dirty $isDirty
        })

    # Ctrl+S shortcut on editor
    $Window.FindName("editorTextBox").Add_KeyDown({
            if ($_.Key -eq [System.Windows.Input.Key]::S -and
                [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl)) {
                Save-EditorFile -Window $Window
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

            $editorBox = $Window.FindName("editorTextBox")
            $statusText = $Window.FindName("editorStatusText")
            Open-FileInEditor -FilePath $currentFile `
                -EditorBox $editorBox `
                -StatusText $statusText `
                -Window $Window
        })

    # New Decision Log button
    $Window.FindName("btnNewDecisionLog").Add_Click({
            $combo = $Window.FindName("editorProjectCombo")
            $proj = Get-SelectedEditorProject -ComboText $combo.Text
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
                $fileTree = $Window.FindName("editorFileTree")
                $workspaceTree = $Window.FindName("editorWorkspaceTree")
                $editorBox = $Window.FindName("editorTextBox")
                $statusText = $Window.FindName("editorStatusText")

                # Refresh tree and open new file
                Populate-FileTree `
                    -Tree            $fileTree `
                    -WorkspaceTree   $workspaceTree `
                    -ProjectInfo     $proj `
                    -WorkspaceRoot   $script:AppState.WorkspaceRoot `
                    -Window          $Window

                Open-FileInEditor -FilePath $newFile `
                    -EditorBox $editorBox `
                    -StatusText $statusText `
                    -Window $Window
            }
        })

    # Fire initial SelectionChanged: goes from -1 to 0, which triggers the handler
    if ($editorProjectCombo.Items.Count -gt 0) {
        $editorProjectCombo.SelectedIndex = 0
    }
}
