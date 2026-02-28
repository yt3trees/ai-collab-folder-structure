# TabSettings.ps1 - Settings tab for hotkey configuration and startup management

function Initialize-TabSettings {
    param(
        [System.Windows.Window]$Window,
        [string]$ScriptDir
    )

    # --- Modifier checkboxes ---
    $chkCtrl = $Window.FindName("settingsModCtrl")
    $chkShift = $Window.FindName("settingsModShift")
    $chkAlt = $Window.FindName("settingsModAlt")
    $chkWin = $Window.FindName("settingsModWin")
    $txtKey = $Window.FindName("settingsKeyInput")
    $lblCurrent = $Window.FindName("settingsCurrentHotkey")
    $btnSave = $Window.FindName("btnSettingsSave")
    $chkStartup = $Window.FindName("settingsStartup")
    $txtOutput = $Window.FindName("txtSettingsOutput")

    # Load current config
    $config = Get-HotkeyConfig
    $modParts = $config.Modifiers -split '\+' | ForEach-Object { $_.Trim().ToLower() }

    $chkCtrl.IsChecked = $modParts -contains "ctrl" -or $modParts -contains "control"
    $chkShift.IsChecked = $modParts -contains "shift"
    $chkAlt.IsChecked = $modParts -contains "alt"
    $chkWin.IsChecked = $modParts -contains "win"
    $txtKey.Text = $config.Key
    $lblCurrent.Text = Get-HotkeyDisplayString

    # Startup checkbox
    $chkStartup.IsChecked = Test-StartupRegistered

    # Save button handler
    $btnSave.Add_Click({
            $chkCtrl = $Window.FindName("settingsModCtrl")
            $chkShift = $Window.FindName("settingsModShift")
            $chkAlt = $Window.FindName("settingsModAlt")
            $chkWin = $Window.FindName("settingsModWin")
            $txtKey = $Window.FindName("settingsKeyInput")
            $lblCurrent = $Window.FindName("settingsCurrentHotkey")
            $chkStartup = $Window.FindName("settingsStartup")
            $txtOutput = $Window.FindName("txtSettingsOutput")

            $txtOutput.Text = ""

            # Build modifiers string
            $mods = @()
            if ($chkCtrl.IsChecked) { $mods += "Ctrl" }
            if ($chkShift.IsChecked) { $mods += "Shift" }
            if ($chkAlt.IsChecked) { $mods += "Alt" }
            if ($chkWin.IsChecked) { $mods += "Win" }

            $keyVal = $txtKey.Text.Trim().ToUpper()

            if ($mods.Count -eq 0) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.Text = "Error: At least one modifier key (Ctrl/Shift/Alt/Win) is required."
                return
            }

            if ([string]::IsNullOrWhiteSpace($keyVal)) {
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.Text = "Error: Key field cannot be empty."
                return
            }

            $modsString = $mods -join "+"

            # Unregister old hotkey
            Unregister-GlobalHotkey

            # Save to paths.json
            $saved = Save-HotkeyConfig -Modifiers $modsString -Key $keyVal

            if ($saved) {
                # Re-register with new hotkey
                $registered = Register-GlobalHotkey -Window $Window
                $lblCurrent.Text = Get-HotkeyDisplayString
                Update-TrayHotkeyDisplay

                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#a6e3a1")
                )
                if ($registered) {
                    $txtOutput.Text = "Hotkey saved and registered: $modsString+$keyVal"
                }
                else {
                    $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                        [System.Windows.Media.ColorConverter]::ConvertFromString("#f9e2af")
                    )
                    $txtOutput.Text = "Hotkey saved but registration failed. The key combination may be in use by another application."
                }
            }
            else {
                # Restore old hotkey
                Register-GlobalHotkey -Window $Window
                $txtOutput.Foreground = [System.Windows.Media.SolidColorBrush](
                    [System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8")
                )
                $txtOutput.Text = "Error: Failed to save hotkey configuration to paths.json."
            }

            # Handle startup toggle
            if ($chkStartup.IsChecked) {
                if (-not (Test-StartupRegistered)) {
                    $startupOk = Register-Startup
                    if ($startupOk) {
                        $txtOutput.Text += "`nStartup registration: Enabled"
                    }
                    else {
                        $txtOutput.Text += "`nStartup registration: Failed"
                    }
                }
            }
            else {
                if (Test-StartupRegistered) {
                    Unregister-Startup | Out-Null
                    $txtOutput.Text += "`nStartup registration: Disabled"
                }
            }
        })

    # Clear button
    $btnSettingsClear = $Window.FindName("btnSettingsClear")
    if ($null -ne $btnSettingsClear) {
        $btnSettingsClear.Add_Click({
                $Window.FindName("txtSettingsOutput").Text = ""
            })
    }
}
