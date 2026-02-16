[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [Parameter()]
    [ValidateSet("fulltext", "filename", "heading", "tag")]
    [string]$SearchType = "fulltext",

    [Parameter()]
    [string]$Folder = "",

    [Parameter()]
    [int]$Context = 1,

    [Parameter()]
    [int]$MaxResults = 20
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load vault path from config.json (fallback to env var)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseDir = Split-Path -Parent $scriptDir
$configPath = Join-Path $baseDir "config.json"
$vaultPath = $null
if (Test-Path $configPath) {
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $vaultPath = $config.vaultPath
    if ($vaultPath) {
        $vaultPath = [System.Environment]::ExpandEnvironmentVariables($vaultPath)
    }
}
if (-not $vaultPath -or -not (Test-Path $vaultPath)) {
    $vaultPath = $env:OBSIDIAN_VAULT_PATH
}
if (-not $vaultPath) {
    Write-Error "Vault path is not configured. Please set it in config.json or the OBSIDIAN_VAULT_PATH environment variable."
    exit 1
}
if (-not (Test-Path $vaultPath)) {
    Write-Error "Vault path not found: $vaultPath"
    exit 1
}

$searchPath = $vaultPath
if ($Folder) {
    $searchPath = Join-Path $vaultPath $Folder
    if (-not (Test-Path $searchPath)) {
        Write-Error "Folder not found: $searchPath"
        exit 1
    }
}

# Bulk read with ReadAllText, split lines only for matched files (optimized for Box sync folders)
$files = Get-ChildItem -Path $searchPath -Filter "*.md" -Recurse

switch ($SearchType) {
    "fulltext" {
        # Fulltext search using ripgrep (rg.exe) from bin directory
        $rgExe = Get-ChildItem -Path (Join-Path $baseDir "bin") -Recurse -Filter "rg.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName

        if (-not $rgExe -or -not (Test-Path $rgExe)) {
            Write-Error "ripgrep (rg.exe) not found. Please extract ripgrep under the bin directory."
            exit 1
        }

        $rgArgs = @(
            "--color", "never",
            "--line-number",
            "--no-heading",
            "--with-filename",
            "--encoding", "utf-8",
            "--glob", "*.md",
            "--context", $Context,
            "--",
            $Pattern,
            $searchPath
        )

        $rgOutput = @()
        $exitCode = 0

        try {
            $rgOutput = & $rgExe @rgArgs
            $exitCode = $LASTEXITCODE
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match "not a valid Win32 application") {
                Write-Error "ripgrep (rg.exe) is not compatible with this OS/CPU architecture. Please place the correct build (e.g. x86_64-pc-windows-msvc) under the bin directory."
                exit 1
            }
            throw
        }

        switch ($exitCode) {
            0 {
                # Normalize rg raw output to PATH/LINE/TYPE/TEXT format
                $matchCount = 0

                foreach ($line in $rgOutput) {
                    if (-not $line) { continue }
                    if ($line -eq "--") { continue }

                    # Match line: path:line:text
                    if ($line -match "^(?<path>.*?):(?<lineno>\d+):(?<text>.*)$") {
                        $type = "match"
                    }
                    # Context line: path-line-text
                    elseif ($line -match "^(?<path>.*?)-(?<lineno>\d+)-(?<text>.*)$") {
                        $type = "context"
                    } else {
                        continue
                    }

                    $path = $matches["path"]
                    $lineno = [int]$matches["lineno"]
                    $text = $matches["text"].TrimEnd()

                    # Convert absolute path to relative path from vault
                    $relativePath = $path.Replace($vaultPath, "").TrimStart("\", "/")

                    if ($type -eq "match") {
                        $matchCount++
                    }

                    Write-Output ("PATH:{0}|LINE:{1}|TYPE:{2}|TEXT:{3}" -f $relativePath, $lineno, $type, $text)

                    if ($matchCount -ge $MaxResults) {
                        break
                    }
                }

                if ($matchCount -eq 0) {
                    Write-Output "No results found: '$Pattern'"
                }
                break
            }
            1 {
                Write-Output "No results found: '$Pattern'"
                break
            }
            default {
                Write-Error "ripgrep execution error. (exit code: $exitCode)"
                exit $exitCode
            }
        }
    }
    "filename" {
        $results = $files |
            Where-Object { $_.Name -like "*$Pattern*" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $MaxResults
        if ($results) {
            foreach ($r in $results) {
                $relativePath = $r.FullName.Replace($vaultPath, "").TrimStart("\", "/")
                $updated = $r.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
                Write-Output "PATH:$relativePath|UPDATED:$updated"
            }
        } else {
            Write-Output "No results found: no notes with '$Pattern' in filename."
        }
    }
    "heading" {
        $count = 0
        foreach ($file in $files) {
            if ($count -ge $MaxResults) { break }
            try {
                $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
            } catch {
                continue
            }
            if ($text -notmatch "^#{1,6} ") { continue }
            $lines = $text -split "`n"
            $relativePath = $file.FullName.Replace($vaultPath, "").TrimStart("\", "/")
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($count -ge $MaxResults) { break }
                if ($lines[$i] -match "^#{1,6} .*$Pattern") {
                    $lineText = $lines[$i].TrimEnd()
                    $lineNo = $i + 1
                    Write-Output "PATH:$relativePath|LINE:$lineNo|TYPE:heading|TEXT:$lineText"
                    $count++
                }
            }
        }
        if ($count -eq 0) {
            Write-Output "No results found: no headings matching '$Pattern'."
        }
    }
    "tag" {
        $tagPattern = "#$Pattern"
        $escapedTag = [regex]::Escape($tagPattern)
        $count = 0
        foreach ($file in $files) {
            if ($count -ge $MaxResults) { break }
            try {
                $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
            } catch {
                continue
            }
            if ($text -notmatch $escapedTag) { continue }
            $lines = $text -split "`n"
            $relativePath = $file.FullName.Replace($vaultPath, "").TrimStart("\", "/")
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($count -ge $MaxResults) { break }
                if ($lines[$i] -match $escapedTag) {
                    $lineText = $lines[$i].Trim()
                    $lineNo = $i + 1
                    Write-Output "PATH:$relativePath|LINE:$lineNo|TYPE:tag|TEXT:$lineText"
                    $count++
                }
            }
        }
        if ($count -eq 0) {
            Write-Output "No results found: no notes with tag '$tagPattern'."
        }
    }
}
