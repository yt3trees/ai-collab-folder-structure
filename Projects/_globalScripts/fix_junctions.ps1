# fix_junctions.ps1 - Create/repair junctions pointing to correct Box paths.
# Reads target paths from paths.json (UTF-8/SJIS safe, no Japanese in script).
# Usage: powershell -ExecutionPolicy Bypass -File fix_junctions.ps1 [-Apply]
param([switch]$Apply)

$root       = Split-Path $PSScriptRoot
$configPath = Join-Path $root "_config\paths.json"

# ---- Read paths.json with encoding detection ----
$rawBytes = [System.IO.File]::ReadAllBytes($configPath)
if ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
    $enc = New-Object System.Text.UTF8Encoding($true)
} else {
    try {
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $null = ($strictUtf8.GetString($rawBytes) | ConvertFrom-Json)
        $enc = New-Object System.Text.UTF8Encoding($false)
    } catch {
        $enc = [System.Text.Encoding]::GetEncoding(932)
    }
}
$json = $enc.GetString($rawBytes)
if ($json.Length -gt 0 -and $json[0] -eq [char]0xFEFF) { $json = $json.Substring(1) }
$cfg = $json | ConvertFrom-Json

$boxProjects   = [System.Environment]::ExpandEnvironmentVariables($cfg.boxProjectsRoot)
$obsidianVault = [System.Environment]::ExpandEnvironmentVariables($cfg.obsidianVaultRoot)

$mode = if ($Apply) { "APPLY" } else { "DRYRUN" }
Write-Host "=== fix_junctions.ps1 [$mode] ===" -ForegroundColor Cyan
Write-Host ""

$createCount = 0
$fixCount    = 0
$skipCount   = 0
$errCount    = 0

# ---- Helper: get junction target via cmd dir /AL on parent ----
function Get-JunctionTarget {
    param([string]$JunctionPath)
    $parent = Split-Path $JunctionPath -Parent
    $name   = [regex]::Escape((Split-Path $JunctionPath -Leaf))
    $cmdEnc = [System.Text.Encoding]::GetEncoding(932)
    $psi = New-Object System.Diagnostics.ProcessStartInfo("cmd.exe", "/c dir /AL `"$parent`"")
    $psi.RedirectStandardOutput = $true
    $psi.StandardOutputEncoding = $cmdEnc
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow   = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $out  = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match "<JUNCTION>\s+$name\s+\[(.+)\]") { return $Matches[1] }
    }
    return $null
}

# ---- Helper: ensure one junction is correct ----
function Invoke-EnsureJunction {
    param([string]$JunctionPath, [string]$ExpectedTarget)

    if (-not (Test-Path $ExpectedTarget)) {
        Write-Host "MISSING-TARGET: $JunctionPath" -ForegroundColor Red
        Write-Host "  target does not exist: $ExpectedTarget"
        $script:errCount++
        return
    }

    $currentTarget = Get-JunctionTarget $JunctionPath
    $pathExists    = Test-Path $JunctionPath  # true only if junction target is accessible

    if ($null -ne $currentTarget) {
        # Junction exists (broken or working)
        if ($currentTarget -eq $ExpectedTarget) {
            Write-Host "OK (already correct): $JunctionPath" -ForegroundColor DarkGray
            $script:skipCount++
            return
        }
        # Wrong target -> need to fix
        Write-Host "FIX: $JunctionPath" -ForegroundColor Yellow
        Write-Host "  OLD -> $currentTarget"
        Write-Host "  NEW -> $ExpectedTarget"
        if ($Apply) {
            try {
                & cmd /c rmdir `"$JunctionPath`" 2>$null | Out-Null
                New-Item -ItemType Junction -Path $JunctionPath -Target $ExpectedTarget -ErrorAction Stop | Out-Null
                Write-Host "  OK" -ForegroundColor Green
                $script:fixCount++
            } catch {
                Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
                $script:errCount++
            }
        } else {
            $script:fixCount++
        }
    } else {
        # Junction does not exist -> create
        Write-Host "CREATE: $JunctionPath" -ForegroundColor Cyan
        Write-Host "  -> $ExpectedTarget"
        if ($Apply) {
            try {
                New-Item -ItemType Junction -Path $JunctionPath -Target $ExpectedTarget -ErrorAction Stop | Out-Null
                Write-Host "  OK" -ForegroundColor Green
                $script:createCount++
            } catch {
                Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
                $script:errCount++
            }
        } else {
            $script:createCount++
        }
    }
}

# ---- Enumerate all project directories ----
function Get-AllProjectDirs {
    $result = @()
    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq '_INHOUSE' -or $_.Name -notmatch '^[_\.]' } |
        ForEach-Object { $result += @{ Dir = $_.FullName; Rel = $_.Name; INHOUSE = ($_.Name -eq '_INHOUSE') } }
    $miniDir = Join-Path $root "_mini"
    if (Test-Path $miniDir) {
        Get-ChildItem $miniDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]' } |
            ForEach-Object { $result += @{ Dir = $_.FullName; Rel = "_mini\$($_.Name)"; INHOUSE = $false } }
    }
    $domainsDir = Join-Path $root "_domains"
    if (Test-Path $domainsDir) {
        Get-ChildItem $domainsDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]' } |
            ForEach-Object { $result += @{ Dir = $_.FullName; Rel = "_domains\$($_.Name)"; INHOUSE = $false } }
        $dmDir = Join-Path $domainsDir "_mini"
        if (Test-Path $dmDir) {
            Get-ChildItem $dmDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '^[_\.]' } |
                ForEach-Object { $result += @{ Dir = $_.FullName; Rel = "_domains\_mini\$($_.Name)"; INHOUSE = $false } }
        }
    }
    return $result
}

foreach ($proj in (Get-AllProjectDirs)) {
    $projDir   = $proj.Dir
    $relPath   = $proj.Rel
    $isInhouse = $proj.INHOUSE
    $aiCtx     = Join-Path $projDir "_ai-context"

    Write-Host "--- $relPath ---" -ForegroundColor White

    # shared
    Invoke-EnsureJunction (Join-Path $projDir "shared") (Join-Path $boxProjects $relPath)

    # context
    if ($isInhouse) {
        Invoke-EnsureJunction (Join-Path $aiCtx "context") (Join-Path $obsidianVault "_INHOUSE\ai-context")
    } else {
        Invoke-EnsureJunction (Join-Path $aiCtx "context") (Join-Path $obsidianVault "Projects\$relPath\ai-context")
    }

    # obsidian_notes
    if ($isInhouse) {
        Invoke-EnsureJunction (Join-Path $aiCtx "obsidian_notes") (Join-Path $obsidianVault "_INHOUSE")
    } else {
        Invoke-EnsureJunction (Join-Path $aiCtx "obsidian_notes") (Join-Path $obsidianVault "Projects\$relPath")
    }
}

Write-Host ""
Write-Host "--- Summary ---"
if ($Apply) {
    Write-Host "Created: $createCount"
    Write-Host "Fixed  : $fixCount"
    Write-Host "Skipped: $skipCount"
    Write-Host "Errors : $errCount"
} else {
    Write-Host "To create: $createCount"
    Write-Host "To fix   : $fixCount"
    Write-Host "Already OK: $skipCount"
    Write-Host "Errors (missing target): $errCount"
    Write-Host ""
    Write-Host "Run with -Apply to execute." -ForegroundColor Cyan
}
