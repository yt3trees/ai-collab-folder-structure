# ProjectDiscovery.ps1 - Project discovery and info collection

# Cache for Get-ProjectInfoList (avoid heavy I/O on every tab switch)
$script:ProjectInfoCache = $null
$script:ProjectInfoCacheTime = [datetime]::MinValue
$script:ProjectInfoCacheTTL = 300  # seconds (5 minutes)

# Returns array of simple project name strings (for dropdowns)
function Get-ProjectNameList {
    $root = $script:AppState.WorkspaceRoot
    $projects = @()

    # Regular (full-tier) projects: top-level dirs not starting with _ or . (Exception: _INHOUSE)
    $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq '_INHOUSE' -or $_.Name -notmatch '^[_\.]' }
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

    # Append BOX-only projects (exist in BOX but not yet set up locally)
    $projects += Get-BoxOnlyProjects

    return ($projects | Sort-Object)
}

# Returns projects that exist in Box/Projects/ but are not yet set up locally.
# Results are formatted as "Name [Domain][Mini] [BOX]" for use in dropdowns.
function Get-BoxOnlyProjects {
    $cfg = $script:AppState.PathsConfig
    if ($null -eq $cfg) { return @() }

    $boxRoot = $cfg.boxProjectsRoot
    if ([string]::IsNullOrWhiteSpace($boxRoot) -or -not (Test-Path $boxRoot)) { return @() }

    $root = $script:AppState.WorkspaceRoot
    $result = @()

    # Full-tier projects: Box/Projects/{Name}/
    $dirs = Get-ChildItem -Path $boxRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^[_\.]' }
    foreach ($d in $dirs) {
        if (-not (Test-Path (Join-Path $root $d.Name))) {
            $result += "$($d.Name) [BOX]"
        }
    }

    # Mini-tier: Box/Projects/_mini/{Name}/
    $boxMiniDir = Join-Path $boxRoot "_mini"
    if (Test-Path $boxMiniDir) {
        $sDirs = Get-ChildItem -Path $boxMiniDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $sDirs) {
            if (-not (Test-Path (Join-Path $root "_mini\$($d.Name)"))) {
                $result += "$($d.Name) [Mini] [BOX]"
            }
        }
    }

    # Domain full-tier: Box/Projects/_domains/{Name}/
    $boxDomainsDir = Join-Path $boxRoot "_domains"
    if (Test-Path $boxDomainsDir) {
        $dDirs = Get-ChildItem -Path $boxDomainsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $dDirs) {
            if (-not (Test-Path (Join-Path $root "_domains\$($d.Name)"))) {
                $result += "$($d.Name) [Domain] [BOX]"
            }
        }

        # Domain mini-tier: Box/Projects/_domains/_mini/{Name}/
        $boxDomainMiniDir = Join-Path $boxDomainsDir "_mini"
        if (Test-Path $boxDomainMiniDir) {
            $dmDirs = Get-ChildItem -Path $boxDomainMiniDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]' }
            foreach ($d in $dmDirs) {
                if (-not (Test-Path (Join-Path $root "_domains\_mini\$($d.Name)"))) {
                    $result += "$($d.Name) [Domain][Mini] [BOX]"
                }
            }
        }
    }

    return $result
}

# Returns array of ProjectInfo hashtables (for dashboard cards)
# -Force: skip cache and re-scan filesystem
function Get-ProjectInfoList {
    param([switch]$Force, [switch]$SkipTokens)

    # Return cached results if available and fresh
    if (-not $Force -and $null -ne $script:ProjectInfoCache) {
        $age = (Get-Date) - $script:ProjectInfoCacheTime
        if ($age.TotalSeconds -lt $script:ProjectInfoCacheTTL) {
            return $script:ProjectInfoCache
        }
    }

    $root = $script:AppState.WorkspaceRoot
    $projects = @()
    $now = Get-Date

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
        if ($null -eq $item) { return "Missing" }
        # Check if it's a ReparsePoint (junction) and whether it resolves.
        # Use Test-Path "$Path\." instead of Get-ChildItem to avoid enumerating all children.
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            if (-not (Test-Path "$Path\.")) { return "Broken" }
        }
        return "OK"
    }

    # Determine if Python tokenizer is available
    $script:HasPythonTokenizer = $false
    $script:PythonTokenScript = Join-Path (Split-Path $PSScriptRoot) "get_tokens.py"
    if (Get-Command python -ErrorAction SilentlyContinue) {
        if (Test-Path $script:PythonTokenScript) {
            $script:HasPythonTokenizer = $true
        }
    }

    # Helper: get line counts only (python will do tokens in bulk later, or we skip)
    function Get-FileMetrics {
        param([string]$Path)
        if (-not (Test-Path $Path)) { return $null }
        try {
            $item = Get-Item $Path
            $lines = 0
            if ($item.Length -gt 0) {
                # [IO.File]::ReadAllLines is significantly faster than Get-Content | Measure-Object
                $lines = [System.IO.File]::ReadAllLines($Path).Count
            }
            return @{ Lines = $lines }
        }
        catch {
            return $null
        }
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

    # Helper: collect focus_history snapshot dates
    function Get-FocusHistoryDates {
        param([string]$AiContextPath)
        $histDir = Join-Path $AiContextPath "context\focus_history"
        if (-not (Test-Path $histDir)) { return @() }
        $dates = @()
        Get-ChildItem $histDir -Filter "*.md" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.BaseName -match '^\d{4}-\d{2}-\d{2}$') {
                $dates += [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
            }
        }
        return ($dates | Sort-Object)
    }

    # Helper: collect decision_log entry dates
    function Get-DecisionLogDates {
        param([string]$AiContextPath)
        $logDir = Join-Path $AiContextPath "context\decision_log"
        if (-not (Test-Path $logDir)) { return @() }
        $dates = @()
        Get-ChildItem $logDir -Filter "*.md" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "TEMPLATE.md" } |
        ForEach-Object {
            # Format: YYYY-MM-DD_topic.md
            if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})_') {
                $dateStr = $Matches[1]
                $dates += [datetime]::ParseExact($dateStr, "yyyy-MM-dd", $null)
            }
        }
        return ($dates | Sort-Object)
    }

    # Process a single project directory
    function New-ProjectInfo {
        param([string]$Name, [string]$Path, [string]$Tier, [string]$Category = "project")

        $aiCtx = Join-Path $Path "_ai-context"
        $aiCtxContent = Join-Path $aiCtx "context"  # junction to Obsidian ai-context/

        # AI file paths (via context/ junction)
        $focusFile = Join-Path $aiCtxContent "current_focus.md"
        $summaryFile = Join-Path $aiCtxContent "project_summary.md"
        $fileMapFile = Join-Path $aiCtxContent "file_map.md"
        $agentsFile = Join-Path $Path "AGENTS.md"
        $claudeFile = Join-Path $Path "CLAUDE.md"

        $focusMetrics = Get-FileMetrics $focusFile
        $summaryMetrics = Get-FileMetrics $summaryFile

        $info = @{
            Name                 = $Name
            Tier                 = $Tier
            Category             = $Category
            Path                 = $Path
            AiContextPath        = $aiCtx
            AiContextContentPath = $aiCtxContent
            # Junction status
            JunctionShared       = Get-JunctionStatus (Join-Path $Path "shared")
            JunctionObsidian     = Get-JunctionStatus (Join-Path $aiCtx "obsidian_notes")
            JunctionContext      = Get-JunctionStatus $aiCtxContent
            # AI file paths (null if missing)
            FocusFile            = if (Test-Path $focusFile) { $focusFile }   else { $null }
            SummaryFile          = if (Test-Path $summaryFile) { $summaryFile } else { $null }
            FileMapFile          = if (Test-Path $fileMapFile) { $fileMapFile } else { $null }
            AgentsFile           = if (Test-Path $agentsFile) { $agentsFile }  else { $null }
            ClaudeFile           = if (Test-Path $claudeFile) { $claudeFile }  else { $null }
            # File metrics (Lines)
            FocusLines           = if ($null -ne $focusMetrics) { $focusMetrics.Lines } else { $null }
            SummaryLines         = if ($null -ne $summaryMetrics) { $summaryMetrics.Lines } else { $null }
            # File metrics (Tokens calculated in bulk later)
            FocusTokens          = $null
            SummaryTokens        = $null
            # Freshness & Health
            FocusAge             = Get-FileAgeDays $focusFile
            SummaryAge           = Get-FileAgeDays $summaryFile
            # Decision log count
            DecisionLogCount     = Get-DecisionLogCount $aiCtx
            # Focus history snapshot dates
            FocusHistoryDates    = Get-FocusHistoryDates $aiCtx
            # Decision log dates
            DecisionLogDates     = Get-DecisionLogDates $aiCtx
        }
        return $info
    }

    # Full-tier projects (Exception: _INHOUSE)
    $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq '_INHOUSE' -or $_.Name -notmatch '^[_\.]' }
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

    # Bulk calculate tokens using python (only on explicit refresh, not on automatic cache-miss)
    if (-not $SkipTokens -and $script:HasPythonTokenizer) {
        $filesToCount = @()
        foreach ($p in $projects) {
            if ($null -ne $p.FocusFile) { $filesToCount += $p.FocusFile }
            if ($null -ne $p.SummaryFile) { $filesToCount += $p.SummaryFile }
        }
        
        if ($filesToCount.Count -gt 0) {
            # Build proper argument list array
            $argsToPass = @("--files")
            foreach ($f in $filesToCount) { $argsToPass += $f }
            
            $pyOut = & python $script:PythonTokenScript @argsToPass 2>$null
            if ($LASTEXITCODE -eq 0 -and (-not [string]::IsNullOrWhiteSpace($pyOut))) {
                try {
                    $tokenDataRaw = $pyOut | ConvertFrom-Json
                    # Convert PSCustomObject to hashtable (PS 5.1 compatible)
                    $tokenData = @{}
                    foreach ($prop in $tokenDataRaw.PSObject.Properties) {
                        $tokenData[$prop.Name.ToLowerInvariant()] = $prop.Value
                    }
                    
                    # Map tokens back to projects
                    foreach ($p in $projects) {
                        if ($null -ne $p.FocusFile) {
                            $key = $p.FocusFile.ToLowerInvariant()
                            if ($tokenData.ContainsKey($key)) {
                                $p.FocusTokens = $tokenData[$key]
                            }
                        }
                        if ($null -ne $p.SummaryFile) {
                            $key = $p.SummaryFile.ToLowerInvariant()
                            if ($tokenData.ContainsKey($key)) {
                                $p.SummaryTokens = $tokenData[$key]
                            }
                        }
                    }
                }
                catch {
                    # JSON parse error, skip token injection
                }
            }
        }
    }

    $script:AppState.Projects = $projects
    $script:ProjectInfoCache = $projects | Sort-Object Name
    $script:ProjectInfoCacheTime = Get-Date

    return $script:ProjectInfoCache
}
