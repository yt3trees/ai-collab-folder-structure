# FeatureMorningBriefing.ps1 - Generates a 72-hour cross-project summary

function Invoke-MorningBriefing {
    param([System.Windows.Window]$Window)
    
    # 1. Prepare Output Path
    $workspaceRoot = $script:AppState.WorkspaceRoot
    $briefingsDir = Join-Path $workspaceRoot "_ai-workspace\briefings"
    if (-not (Test-Path $briefingsDir)) {
        # Fallback if _ai-workspace doesn't exist
        $briefingsDir = Join-Path $workspaceRoot "_briefings"
        if (-not (Test-Path $briefingsDir)) {
            New-Item -ItemType Directory -Path $briefingsDir -Force | Out-Null
        }
    }
    
    $today = Get-Date
    $filename = "$($today.ToString('yyyy-MM-dd'))_Briefing.md"
    $outputPath = Join-Path $briefingsDir $filename
    
    # 2. Get Data
    $cutoff = $today.AddHours(-72)
    
    # Force refresh project cache to ensure we get latest timestamps
    $projects = Get-ProjectInfoList -Force
    
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("# Morning Briefing") | Out-Null
    $sb.AppendLine("Date: $($today.ToString('yyyy-MM-dd HH:mm'))") | Out-Null
    $sb.AppendLine("Period: Since $($cutoff.ToString('yyyy-MM-dd HH:mm')) (Past 72h)") | Out-Null
    $sb.AppendLine() | Out-Null
    
    $hasActivity = $false
    
    # Asana parsing helper
    function Get-RecentAsanaTasks {
        param([string]$AsanaFilePath, [datetime]$CutoffDate)
        if (-not (Test-Path $AsanaFilePath)) { return @() }
        
        $tasks = @()
        try {
            # Looking for "- [x] ... (Due: YYYY-MM-DD)" or just "- [x] ..."
            $lines = Get-Content $AsanaFilePath -Encoding UTF8 -ErrorAction SilentlyContinue
            $inCompletedSection = $false
            foreach ($line in $lines) {
                if ($line -match '^###? 完了') {
                    $inCompletedSection = $true
                    continue
                }
                if ($inCompletedSection -and $line -match '^##\s') {
                    $inCompletedSection = $false
                    continue
                }
                if ($inCompletedSection -and $line -match '^\s*-\s+\[x\]\s+(.+)') {
                    # Note: sync_from_asana.py fetches tasks completed in last 7 days.
                    # This implies any [x] in the file is relatively recent.
                    # We'll include all of them under "Recent Completed".
                    $tasks += $line.Trim()
                }
            }
        }
        catch {}
        return $tasks
    }
    
    # Get global Asana tasks (asana-tasks-view.md) if configured
    $obsidianRoot = $script:AppState.PathsConfig.obsidianVaultRoot
    $globalAsanaFile = Join-Path $obsidianRoot "asana-tasks-view.md"
    $globalTasks = Get-RecentAsanaTasks -AsanaFilePath $globalAsanaFile -CutoffDate $cutoff
    
    if ($globalTasks.Count -gt 0) {
        $sb.AppendLine("## Global Asana Tasks (Recently Completed)") | Out-Null
        $sb.AppendLine() | Out-Null
        foreach ($t in $globalTasks) {
            $sb.AppendLine($t) | Out-Null
        }
        $sb.AppendLine() | Out-Null
        $hasActivity = $true
    }
    
    $sb.AppendLine("## Project Updates") | Out-Null
    $sb.AppendLine() | Out-Null
    
    foreach ($proj in $projects) {
        $projActivity = $false
        $projSb = New-Object System.Text.StringBuilder
        $projSb.AppendLine("### $($proj.Name)") | Out-Null
        
        # Check current_focus.md (last modified)
        if ($null -ne $proj.FocusFile -and (Test-Path $proj.FocusFile)) {
            $fileInfo = Get-Item $proj.FocusFile
            if ($fileInfo.LastWriteTime -ge $cutoff) {
                $preview = Get-FocusPreview -FilePath $proj.FocusFile
                $projSb.AppendLine("- **[Focus]** $($preview)") | Out-Null
                $projActivity = $true
            }
        }
        
        # Check decision_log
        $logDir = Join-Path $proj.AiContextContentPath "decision_log"
        if (Test-Path $logDir) {
            $recentLogs = Get-ChildItem $logDir -Filter "*.md" | 
            Where-Object { $_.Name -ne "TEMPLATE.md" -and $_.LastWriteTime -ge $cutoff }
            
            foreach ($log in $recentLogs) {
                # Format: YYYY-MM-DD_topic.md -> topic
                $topic = $log.BaseName
                if ($topic -match '^(\d{4}-\d{2}-\d{2})_(.*)') {
                    $topic = $Matches[2]
                }
                $projSb.AppendLine("- **[Decision]** $($topic)") | Out-Null
                $projActivity = $true
            }
        }
        
        # Check Project Asana
        if ($proj.Name -eq '_INHOUSE') {
            $asanaFile = Join-Path $obsidianRoot "_INHOUSE\asana-tasks.md"
        }
        else {
            # It's difficult to resolve relative path accurately here without full logic,
            # but usually it's under obsidianRoot/ProjectName or obsidianRoot/_domains/ProjectName
            # Actually, sync_from_asana outputs to obsidianVaultRoot / relative_path / asana-tasks.md
            $tier = $proj.Tier
            $cat = $proj.Category
            $relPath = $proj.Name
            if ($cat -eq "domain" -and $tier -eq "mini") { $relPath = "_domains\_mini\$($proj.Name)" }
            elseif ($cat -eq "domain") { $relPath = "_domains\$($proj.Name)" }
            elseif ($tier -eq "mini") { $relPath = "_mini\$($proj.Name)" }
            
            $asanaFile = Join-Path (Join-Path $obsidianRoot $relPath) "asana-tasks.md"
        }
        
        $pTasks = Get-RecentAsanaTasks -AsanaFilePath $asanaFile -CutoffDate $cutoff
        if ($pTasks.Count -gt 0) {
            foreach ($t in $pTasks) {
                $projSb.AppendLine("    - [Asana] $($t -replace '^\s*-\s+\[x\]\s+', '')") | Out-Null
            }
            $projActivity = $true
        }
        
        if ($projActivity) {
            $sb.AppendLine($projSb.ToString().TrimEnd()) | Out-Null
            $sb.AppendLine() | Out-Null
            $hasActivity = $true
        }
    }
    
    if (-not $hasActivity) {
        $sb.AppendLine("*No activity found in the last 72 hours.*") | Out-Null
    }
    
    # 3. Write and Open
    # Create _ai-workspace parent folder if somehow it's a new path
    $parent = Split-Path $outputPath
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    
    # Save purely as UTF8 no BOM
    [System.IO.File]::WriteAllText($outputPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    
    # 4. Open in Editor
    # Use existing EditorHelpers function
    $tabMain = $Window.FindName("tabMain")
    if ($null -ne $tabMain) {
        $tabMain.SelectedIndex = 1  # 1 = Editor
    }
    
    Open-FileInEditor -FilePath $outputPath -Window $Window
}
