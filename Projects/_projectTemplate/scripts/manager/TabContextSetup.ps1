# TabContextSetup.ps1 - AI Context Setup tab event handlers

function Initialize-TabContextSetup {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir,
        [string[]]$ProjectList
    )

    $ctxProjectCombo = $Window.FindName("ctxProjectCombo")
    $btnCtxLayer = $Window.FindName("btnCtxLayer")
    $btnCtxClear = $Window.FindName("btnCtxClear")

    # Populate dropdown
    foreach ($p in $ProjectList) {
        $ctxProjectCombo.Items.Add($p) | Out-Null
    }

    $btnCtxClear.Add_Click({
            $out = $Window.FindName("txtCtxOutput")
            $out.Text = ""
        })

    $btnCtxLayer.Add_Click({
            $combo = $Window.FindName("ctxProjectCombo")
            $mini = $Window.FindName("ctxMini")
            $params = Get-ProjectParams -ComboText $combo.Text `
                -MiniChecked $mini.IsChecked

            $argStr = ""
            if (-not [string]::IsNullOrEmpty($params.Name)) {
                $argStr = "-ProjectName '$($params.Name)'"
                if ($params.IsMini) { $argStr += " -Mini" }
                if ($params.IsDomain) { $argStr += " -Category domain" }
            }

            # context-compression-layer setup script is two levels up from scripts/
            $scriptPath = Join-Path (Split-Path $ScriptDir) `
                "context-compression-layer\setup_context_layer.ps1"

            $outputBox = $Window.FindName("txtCtxOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
