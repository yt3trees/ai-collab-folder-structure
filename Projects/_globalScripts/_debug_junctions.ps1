$root       = Split-Path $PSScriptRoot
$configPath = Join-Path $root "_config\paths.json"
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

$boxOk = Test-Path $boxProjects
$obsOk = Test-Path $obsidianVault
$projOk = Test-Path (Join-Path $boxProjects "ProjectA")
$aiOk  = Test-Path (Join-Path $obsidianVault "Projects\ProjectA\ai-context")

[System.IO.File]::WriteAllText("$root\_config\_pathcheck.txt",
    "boxProjects=$boxProjects`r`nboxOK=$boxOk`r`nobsidianVault=$obsidianVault`r`nobsOK=$obsOk`r`nprojOK=$projOk`r`naiOK=$aiOk`r`n",
    [System.Text.Encoding]::UTF8)
Write-Host "Written to _pathcheck.txt"
Write-Host "boxOK=$boxOk obsOK=$obsOk projOK=$projOk aiOK=$aiOk"
