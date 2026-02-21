# EditorHelpers.ps1 - File I/O with encoding detection and dirty-state tracking

# Detect encoding from BOM or content analysis
function Get-FileEncoding {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    # Check BOM
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return "UTF8BOM"
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return "UTF16LE"
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return "UTF16BE"
    }

    # Try UTF-8 strict (no BOM)
    try {
        $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
        $utf8Strict.GetString($bytes) | Out-Null
        return "UTF8"
    }
    catch {
        # Not valid UTF-8 -> assume Shift_JIS
        return "SJIS"
    }
}

# Read file content respecting detected encoding
function Read-FileContent {
    param([string]$Path)

    $encoding = Get-FileEncoding -Path $Path

    $enc = switch ($encoding) {
        "UTF8BOM" { New-Object System.Text.UTF8Encoding($true) }
        "UTF16LE" { [System.Text.Encoding]::Unicode }
        "UTF16BE" { [System.Text.Encoding]::BigEndianUnicode }
        "SJIS" { [System.Text.Encoding]::GetEncoding(932) }
        default { [System.Text.Encoding]::UTF8 }  # UTF8 (no BOM)
    }

    $content = [System.IO.File]::ReadAllText($Path, $enc)
    return @{
        Content  = $content
        Encoding = $encoding
    }
}

# Save file preserving original encoding
function Save-FileContent {
    param(
        [string]$Path,
        [string]$Content,
        [string]$Encoding
    )

    $enc = switch ($Encoding) {
        "UTF8BOM" { New-Object System.Text.UTF8Encoding($true) }
        "UTF16LE" { [System.Text.Encoding]::Unicode }
        "UTF16BE" { [System.Text.Encoding]::BigEndianUnicode }
        "SJIS" { [System.Text.Encoding]::GetEncoding(932) }
        default { New-Object System.Text.UTF8Encoding($false) }  # UTF8 no BOM
    }

    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# Open a file into the AvalonEdit editor and update AppState
function Open-FileInEditor {
    param(
        [string]$FilePath,
        [System.Windows.Window]$Window
    )

    if ([string]::IsNullOrEmpty($FilePath) -or -not (Test-Path $FilePath)) {
        return
    }

    $editor = $script:AppState.EditorControl
    if ($null -eq $editor) { return }

    # Warn about unsaved changes
    if ($script:AppState.EditorState.IsDirty) {
        $result = [System.Windows.MessageBox]::Show(
            "Unsaved changes in '$([System.IO.Path]::GetFileName($script:AppState.EditorState.CurrentFile))'.`nDiscard changes?",
            "Unsaved Changes",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    try {
        $result = Read-FileContent -Path $FilePath

        # Update AppState BEFORE setting text (so Changed handler sees correct OriginalContent)
        $script:AppState.EditorState.CurrentFile = $FilePath
        $script:AppState.EditorState.OriginalContent = $result.Content
        $script:AppState.EditorState.IsDirty = $false
        $script:AppState.EditorState.Encoding = $result.Encoding

        # Suppress dirty-flag while loading text
        $script:AppState.EditorState.SuppressChangeEvent = $true
        $editor.Text = $result.Content
        $script:AppState.EditorState.SuppressChangeEvent = $false

        $editor.IsReadOnly = $false

        $btnEditorSave = $Window.FindName("btnEditorSave")
        $btnEditorReload = $Window.FindName("btnEditorReload")
        if ($null -ne $btnEditorSave) { $btnEditorSave.IsEnabled = $true }
        if ($null -ne $btnEditorReload) { $btnEditorReload.IsEnabled = $true }

        $fileName = [System.IO.Path]::GetFileName($FilePath)

        # Update status bar
        Update-StatusBar -Window $Window `
            -File $fileName `
            -Encoding $result.Encoding `
            -Dirty $false

        $editor.TextArea.Caret.Offset = 0
        $editor.ScrollToLine(1)
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Failed to open file:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}

# Save the currently open file
function Save-EditorFile {
    param([System.Windows.Window]$Window)

    $state = $script:AppState.EditorState
    if ([string]::IsNullOrEmpty($state.CurrentFile)) { return }

    $editor = $script:AppState.EditorControl
    if ($null -eq $editor) { return }

    try {
        # Auto-snapshot: if saving current_focus.md, archive previous version to focus_history/
        $fileName = [System.IO.Path]::GetFileName($state.CurrentFile)
        if ($fileName -eq "current_focus.md") {
            Save-FocusSnapshot -FilePath $state.CurrentFile `
                -OriginalContent $state.OriginalContent `
                -Encoding $state.Encoding
        }

        Save-FileContent -Path $state.CurrentFile `
            -Content $editor.Text `
            -Encoding $state.Encoding

        $state.OriginalContent = $editor.Text
        $state.IsDirty = $false

        Update-StatusBar -Window $Window `
            -File ([System.IO.Path]::GetFileName($state.CurrentFile)) `
            -Encoding $state.Encoding `
            -Dirty $false
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Failed to save file:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}

# Auto-snapshot current_focus.md to focus_history/YYYY-MM-DD.md
function Save-FocusSnapshot {
    param(
        [string]$FilePath,
        [string]$OriginalContent,
        [string]$Encoding
    )

    # Skip if original content is empty or template-only
    if ([string]::IsNullOrWhiteSpace($OriginalContent)) { return }

    # Strip HTML comments and check for real content
    $stripped = $OriginalContent -replace '(?s)<!--.*?-->', ''
    $lines = ($stripped -split "`n") | ForEach-Object { $_.Trim() }
    $contentLines = $lines | Where-Object {
        $_ -ne "" -and
        $_ -ne "-" -and
        -not $_.StartsWith("#") -and
        -not $_.StartsWith("---") -and
        -not ($_ -match '^更新:')
    }
    if ($contentLines.Count -eq 0) { return }

    # Determine focus_history/ directory
    $parentDir = [System.IO.Path]::GetDirectoryName($FilePath)
    $historyDir = Join-Path $parentDir "focus_history"

    if (-not (Test-Path $historyDir)) {
        New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
    }

    # Save snapshot with today's date (overwrite if same day)
    $today = Get-Date -Format "yyyy-MM-dd"
    $snapshotPath = Join-Path $historyDir "$today.md"

    $enc = switch ($Encoding) {
        "UTF8BOM" { New-Object System.Text.UTF8Encoding($true) }
        "UTF16LE" { [System.Text.Encoding]::Unicode }
        "UTF16BE" { [System.Text.Encoding]::BigEndianUnicode }
        "SJIS" { [System.Text.Encoding]::GetEncoding(932) }
        default { New-Object System.Text.UTF8Encoding($false) }
    }

    [System.IO.File]::WriteAllText($snapshotPath, $OriginalContent, $enc)
}

# Create a new decision log file from template
function New-DecisionLog {
    param(
        [string]$AiContextPath,
        [System.Windows.Window]$Window
    )

    # Prompt for topic
    $topic = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Enter decision topic (used in filename, e.g. 'api-design'):",
        "New Decision Log",
        ""
    )

    if ([string]::IsNullOrWhiteSpace($topic)) { return $null }

    # Sanitize topic for filename
    $safeTopic = $topic.Trim() -replace '[^\w\-]', '_'
    $date = Get-Date -Format "yyyy-MM-dd"
    $filename = "${date}_${safeTopic}.md"
    $logDir = Join-Path $AiContextPath "context\decision_log"
    $newPath = Join-Path $logDir $filename

    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Copy from template if available
    $templatePath = Join-Path $logDir "TEMPLATE.md"
    if (Test-Path $templatePath) {
        $tmplResult = Read-FileContent -Path $templatePath
        $content = $tmplResult.Content
    }
    else {
        $content = @"
# Decision: $topic

Date: $date

## Context

## Decision

## Consequences

"@
    }

    [System.IO.File]::WriteAllText($newPath, $content, [System.Text.Encoding]::UTF8)
    return $newPath
}
