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
    $ctxMini = $Window.FindName("ctxMini")
    $ctxDomain = $Window.FindName("ctxDomain")
    $ctxForce = $Window.FindName("ctxForce")

    # Populate dropdown
    foreach ($p in $ProjectList) {
        $ctxProjectCombo.Items.Add($p) | Out-Null
    }

    # Auto-toggle checkboxes on combo selection
    $ctxProjectCombo.Add_SelectionChanged({
            $combo = $Window.FindName("ctxProjectCombo")
            $comboText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
            if ([string]::IsNullOrWhiteSpace($comboText)) { return }

            $params = Get-ProjectParams -ComboText $comboText -MiniChecked $false -DomainChecked $false
            $Window.FindName("ctxMini").IsChecked = $params.IsMini
            $Window.FindName("ctxDomain").IsChecked = $params.IsDomain
        })

    $btnCtxClear.Add_Click({
            $out = $Window.FindName("txtCtxOutput")
            $out.Text = ""
        })

    $btnCtxLayer.Add_Click({
            $combo = $Window.FindName("ctxProjectCombo")
            $mini = $Window.FindName("ctxMini")
            $domain = $Window.FindName("ctxDomain")
            $force = $Window.FindName("ctxForce")
            $params = Get-ProjectParams -ComboText $combo.Text `
                -MiniChecked $mini.IsChecked -DomainChecked $domain.IsChecked

            $argStr = ""
            if (-not [string]::IsNullOrEmpty($params.Name)) {
                $argStr = "-ProjectName '$($params.Name)'"
                if ($params.IsMini) { $argStr += " -Mini" }
                if ($params.IsDomain) { $argStr += " -Category domain" }
            }
            if ($force.IsChecked) { $argStr += " -Force" }

            # context-compression-layer setup script is two levels up from scripts/
            $scriptPath = Join-Path (Split-Path $ScriptDir) `
                "context-compression-layer\setup_context_layer.ps1"

            $outputBox = $Window.FindName("txtCtxOutput")
            Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr `
                -OutputBox $outputBox -WindowRef $Window
        })
}
