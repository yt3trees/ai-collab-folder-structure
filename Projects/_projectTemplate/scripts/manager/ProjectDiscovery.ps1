# ProjectDiscovery.ps1 - Project discovery and info collection

# Returns array of simple project name strings (for dropdowns)
function Get-ProjectNameList {
    $root = $script:AppState.WorkspaceRoot
    $projects = @()

    # Regular (full-tier) projects: top-level dirs not starting with _ or .
    $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]'  }
    foreach ($d in $dirs) { $projects += $d.Name }

    # Mini-tier projects under _mini/
    $miniDir = Join-Path $root "_mini"
    if (Test-Path $miniDir) {
        $sDirs = Get-ChildItem -Path $miniDir -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $sDirs) { $projects += "$($d.Name) [Mini]" }
    }

    # Domain (full-tier) projects under _domains/
    $domainsDir = Join-Path $root "_domains"
    if (Test-Path $domainsDir) {
        $dDirs = Get-ChildItem -Path $domainsDir -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $dDirs) { $projects += "$($d.Name) [Domain]" }

        # Domain mini-tier projects under _domains/_mini/
        $domainMiniDir = Join-Path $domainsDir "_mini"
        if (Test-Path $domainMiniDir) {
            $dmDirs = Get-ChildItem -Path $domainMiniDir -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -notmatch '^[_\.]' }
            foreach ($d in $dmDirs) { $projects += "$($d.Name) [Domain][Mini]" }
        }
    }

    return ($projects | Sort-Object)
}

# Returns array of ProjectInfo hashtables (for dashboard cards)
function Get-ProjectInfoList {
    $root     = $script:AppState.WorkspaceRoot
    $projects = @()
    $now      = Get-Date

    # Helper: get file age in days, or $null if not found
    function Get-FileAgeDays {
        param([string]$Path)
        if (Test-Path $Path) {
            $diff = $now - (Get-Item $Path).LastWriteTime
            return [int]$diff.TotalDays
        }
        return $null
    }

    # Helper: check junction/directory status
    function Get-JunctionStatus {
        param([string]$Path)
        if (-not (Test-Path $Path)) { return "Missing" }
        $item = Get-Item $Path -ErrorAction SilentlyContinue
        if ($null -eq $item)        { return "Missing" }
        # Check if it's a ReparsePoint (junction) and whether it resolves
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            # Try to list children to detect broken junctions
            $children = Get-ChildItem $Path -ErrorAction SilentlyContinue
            if ($null -eq $children -and -not (Test-Path "$Path\.")) {
                return "Broken"
            }
            return "OK"
        }
        return "OK"
    }

    # Helper: count decision log files
    function Get-DecisionLogCount {
        param([string]$AiContextPath)
        # Files live in context/decision_log/ (via junction)
        $logDir = Join-Path $AiContextPath "context\decision_log"
        if (-not (Test-Path $logDir)) { return 0 }
        $mdFiles = Get-ChildItem $logDir -Filter "*.md" -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -ne "TEMPLATE.md" }
        return ($mdFiles | Measure-Object).Count
    }

    # Process a single project directory
    function New-ProjectInfo {
        param([string]$Name, [string]$Path, [string]$Tier, [string]$Category = "project")

        $aiCtx        = Join-Path $Path "_ai-context"
        $aiCtxContent = Join-Path $aiCtx "context"  # junction to Obsidian ai-context/

        # AI file paths (via context/ junction)
        $focusFile   = Join-Path $aiCtxContent "current_focus.md"
        $summaryFile = Join-Path $aiCtxContent "project_summary.md"
        $fileMapFile = Join-Path $aiCtxContent "file_map.md"
        $agentsFile  = Join-Path $Path "AGENTS.md"
        $claudeFile  = Join-Path $Path "CLAUDE.md"

        $info = @{
            Name                = $Name
            Tier                = $Tier
            Category            = $Category
            Path                = $Path
            AiContextPath       = $aiCtx
            AiContextContentPath = $aiCtxContent
            # Junction status
            JunctionShared   = Get-JunctionStatus (Join-Path $Path "shared")
            JunctionObsidian = Get-JunctionStatus (Join-Path $aiCtx "obsidian_notes")
            JunctionContext  = Get-JunctionStatus $aiCtxContent
            # AI file paths (null if missing)
            FocusFile        = if (Test-Path $focusFile)   { $focusFile }   else { $null }
            SummaryFile      = if (Test-Path $summaryFile) { $summaryFile } else { $null }
            FileMapFile      = if (Test-Path $fileMapFile) { $fileMapFile } else { $null }
            AgentsFile       = if (Test-Path $agentsFile)  { $agentsFile }  else { $null }
            ClaudeFile       = if (Test-Path $claudeFile)  { $claudeFile }  else { $null }
            # Freshness
            FocusAge         = Get-FileAgeDays $focusFile
            SummaryAge       = Get-FileAgeDays $summaryFile
            # Decision log count
            DecisionLogCount = Get-DecisionLogCount $aiCtx
        }
        return $info
    }

    # Full-tier projects
    $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]'  }
    foreach ($d in $dirs) {
        $projects += New-ProjectInfo -Name $d.Name -Path $d.FullName -Tier "full"
    }

    # Mini-tier projects
    $miniDir = Join-Path $root "_mini"
    if (Test-Path $miniDir) {
        $sDirs = Get-ChildItem -Path $miniDir -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $sDirs) {
            $projects += New-ProjectInfo -Name $d.Name -Path $d.FullName -Tier "mini"
        }
    }

    # Domain (full-tier) projects
    $domainsDir = Join-Path $root "_domains"
    if (Test-Path $domainsDir) {
        $dDirs = Get-ChildItem -Path $domainsDir -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $dDirs) {
            $projects += New-ProjectInfo -Name $d.Name -Path $d.FullName -Tier "full" -Category "domain"
        }

        # Domain mini-tier projects
        $domainMiniDir = Join-Path $domainsDir "_mini"
        if (Test-Path $domainMiniDir) {
            $dmDirs = Get-ChildItem -Path $domainMiniDir -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -notmatch '^[_\.]' }
            foreach ($d in $dmDirs) {
                $projects += New-ProjectInfo -Name $d.Name -Path $d.FullName -Tier "mini" -Category "domain"
            }
        }
    }

    $script:AppState.Projects = $projects
    return ($projects | Sort-Object { $_.Name })
}
