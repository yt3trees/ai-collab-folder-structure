# TrayManager.ps1 - System Tray Icon and Global Hotkey management
# Provides NotifyIcon integration, context menu, and global hotkey toggle

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Win32 API for Global Hotkey ---
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class HotkeyInterop {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public const int WM_HOTKEY   = 0x0312;
    public const int HOTKEY_ID   = 9000;

    // Modifier flags
    public const uint MOD_ALT     = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT   = 0x0004;
    public const uint MOD_WIN     = 0x0008;
    public const uint MOD_NOREPEAT = 0x4000;
}
'@

$script:TrayState = @{
    NotifyIcon       = $null
    HwndSource       = $null
    Window           = $null
    ForceExit        = $false
    HotkeyRegistered = $false
}

function New-TrayIconImage {
    # Generate a simple diamond icon programmatically (no external .ico needed)
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    # Diamond shape in Catppuccin Mauve (#cba6f7)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 203, 166, 247))
    $points = @(
        [System.Drawing.Point]::new(16, 2),
        [System.Drawing.Point]::new(30, 16),
        [System.Drawing.Point]::new(16, 30),
        [System.Drawing.Point]::new(2, 16)
    )
    $g.FillPolygon($brush, $points)

    # Inner highlight
    $innerBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(180, 180, 190, 254))
    $innerPoints = @(
        [System.Drawing.Point]::new(16, 8),
        [System.Drawing.Point]::new(24, 16),
        [System.Drawing.Point]::new(16, 24),
        [System.Drawing.Point]::new(8, 16)
    )
    $g.FillPolygon($innerBrush, $innerPoints)

    $g.Dispose()
    $brush.Dispose()
    $innerBrush.Dispose()

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    return $icon
}

function Get-HotkeyConfig {
    # Read hotkey settings from paths.json, return defaults if not configured
    $config = $script:AppState.PathsConfig
    $defaults = @{ Modifiers = "Ctrl+Shift"; Key = "P" }

    if ($null -eq $config) { return $defaults }

    # Check if hotkey property exists
    $hotkeyProp = $config.PSObject.Properties | Where-Object { $_.Name -eq "hotkey" }
    if ($null -eq $hotkeyProp -or $null -eq $hotkeyProp.Value) { return $defaults }

    $hk = $hotkeyProp.Value
    return @{
        Modifiers = if ($hk.PSObject.Properties["modifiers"]) { $hk.modifiers } else { $defaults.Modifiers }
        Key       = if ($hk.PSObject.Properties["key"]) { $hk.key }       else { $defaults.Key }
    }
}

function Save-HotkeyConfig {
    param(
        [string]$Modifiers,
        [string]$Key
    )

    $configPath = Join-Path $script:AppState.WorkspaceRoot "_config\paths.json"
    if (-not (Test-Path $configPath)) { return $false }

    try {
        $json = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
        $obj = $json | ConvertFrom-Json

        # Add or update hotkey property
        $hotkeyObj = [PSCustomObject]@{
            modifiers = $Modifiers
            key       = $Key
        }

        $existingProp = $obj.PSObject.Properties | Where-Object { $_.Name -eq "hotkey" }
        if ($null -ne $existingProp) {
            $obj.hotkey = $hotkeyObj
        }
        else {
            $obj | Add-Member -MemberType NoteProperty -Name "hotkey" -Value $hotkeyObj
        }

        $newJson = $obj | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($configPath, $newJson, [System.Text.Encoding]::UTF8)

        # Update in-memory config
        $existingConfigProp = $script:AppState.PathsConfig.PSObject.Properties | Where-Object { $_.Name -eq "hotkey" }
        if ($null -ne $existingConfigProp) {
            $script:AppState.PathsConfig.hotkey = $hotkeyObj
        }
        else {
            $script:AppState.PathsConfig | Add-Member -MemberType NoteProperty -Name "hotkey" -Value $hotkeyObj
        }

        return $true
    }
    catch {
        return $false
    }
}

function ConvertTo-ModifierFlags {
    param([string]$ModifiersString)
    # Parse "Ctrl+Shift" into Win32 modifier flags
    [uint32]$flags = [HotkeyInterop]::MOD_NOREPEAT
    $parts = $ModifiersString -split '\+'
    foreach ($part in $parts) {
        switch ($part.Trim().ToLower()) {
            "ctrl" { $flags = $flags -bor [HotkeyInterop]::MOD_CONTROL }
            "control" { $flags = $flags -bor [HotkeyInterop]::MOD_CONTROL }
            "shift" { $flags = $flags -bor [HotkeyInterop]::MOD_SHIFT }
            "alt" { $flags = $flags -bor [HotkeyInterop]::MOD_ALT }
            "win" { $flags = $flags -bor [HotkeyInterop]::MOD_WIN }
        }
    }
    return $flags
}

function ConvertTo-VirtualKeyCode {
    param([string]$KeyName)
    # Convert key name to Win32 virtual key code
    $k = $KeyName.Trim().ToUpper()

    # Single letter A-Z
    if ($k.Length -eq 1 -and $k -match '^[A-Z]$') {
        return [int][char]$k
    }
    # Number 0-9
    if ($k.Length -eq 1 -and $k -match '^[0-9]$') {
        return [int][char]$k
    }
    # Function keys F1-F12
    if ($k -match '^F(\d+)$') {
        $fNum = [int]$Matches[1]
        if ($fNum -ge 1 -and $fNum -le 12) {
            return 0x70 + ($fNum - 1)  # VK_F1 = 0x70
        }
    }
    # Special keys
    switch ($k) {
        "SPACE" { return 0x20 }
        "TAB" { return 0x09 }
        "ESCAPE" { return 0x1B }
        "ESC" { return 0x1B }
    }
    # Fallback: try as character
    if ($k.Length -eq 1) {
        return [int][char]$k
    }
    return 0
}

function Get-HotkeyDisplayString {
    $config = Get-HotkeyConfig
    return "$($config.Modifiers)+$($config.Key)"
}

function Register-GlobalHotkey {
    param([System.Windows.Window]$Window)

    if ($script:TrayState.HotkeyRegistered) {
        Unregister-GlobalHotkey
    }

    $config = Get-HotkeyConfig
    $modFlags = ConvertTo-ModifierFlags -ModifiersString $config.Modifiers
    $vk = ConvertTo-VirtualKeyCode -KeyName $config.Key

    if ($vk -eq 0) { return $false }

    # Get window handle via HwndSource
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($Window)
    $hwnd = $helper.Handle

    if ($hwnd -eq [IntPtr]::Zero) {
        # Window not yet shown, need to ensure handle
        $helper.EnsureHandle() | Out-Null
        $hwnd = $helper.Handle
    }

    # Register the hotkey
    $result = [HotkeyInterop]::RegisterHotKey($hwnd, [HotkeyInterop]::HOTKEY_ID, $modFlags, $vk)

    if ($result) {
        # Hook WndProc to receive WM_HOTKEY
        $source = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
        if ($null -ne $source) {
            $source.AddHook({
                    param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
                    if ($msg -eq [HotkeyInterop]::WM_HOTKEY -and $wParam.ToInt32() -eq [HotkeyInterop]::HOTKEY_ID) {
                        Switch-WindowVisibility
                        $handled.Value = $true
                    }
                    return [IntPtr]::Zero
                })
            $script:TrayState.HwndSource = $source
        }
        $script:TrayState.HotkeyRegistered = $true
    }

    return $result
}

function Unregister-GlobalHotkey {
    if (-not $script:TrayState.HotkeyRegistered) { return }

    $window = $script:TrayState.Window
    if ($null -ne $window) {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        $hwnd = $helper.Handle
        if ($hwnd -ne [IntPtr]::Zero) {
            [HotkeyInterop]::UnregisterHotKey($hwnd, [HotkeyInterop]::HOTKEY_ID) | Out-Null
        }
    }
    $script:TrayState.HotkeyRegistered = $false
}

function Switch-WindowVisibility {
    $window = $script:TrayState.Window
    if ($null -eq $window) { return }

    $window.Dispatcher.Invoke([Action] {
            if ($window.IsVisible) {
                $window.Hide()
            }
            else {
                $window.Show()
                $window.Topmost = $true
                $window.Activate()
                $window.Topmost = $false
            }
        })
}

function Initialize-TrayIcon {
    param([System.Windows.Window]$Window)

    $script:TrayState.Window = $Window

    # Create NotifyIcon
    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = New-TrayIconImage
    $notifyIcon.Text = "Project Manager"
    $notifyIcon.Visible = $true

    # Single click to toggle window
    $notifyIcon.Add_Click({
            param($s, $e)
            if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                Switch-WindowVisibility
            }
        })

    # Context menu
    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $showItem = New-Object System.Windows.Forms.ToolStripMenuItem("Show")
    $showItem.Add_Click({
            $w = $script:TrayState.Window
            if ($null -ne $w) {
                $w.Dispatcher.Invoke([Action] {
                        $w.Show()
                        $w.WindowState = [System.Windows.WindowState]::Normal
                        $w.Activate()
                    })
            }
        })
    $contextMenu.Items.Add($showItem) | Out-Null

    $contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    $hotkeyDisplay = Get-HotkeyDisplayString
    $hotkeyItem = New-Object System.Windows.Forms.ToolStripMenuItem("Hotkey: $hotkeyDisplay")
    $hotkeyItem.Enabled = $false
    $contextMenu.Items.Add($hotkeyItem) | Out-Null

    $contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
    $exitItem.Add_Click({
            Invoke-TrayExit
        })
    $contextMenu.Items.Add($exitItem) | Out-Null

    $notifyIcon.ContextMenuStrip = $contextMenu

    $script:TrayState.NotifyIcon = $notifyIcon
}

function Update-TrayHotkeyDisplay {
    $ni = $script:TrayState.NotifyIcon
    if ($null -eq $ni -or $null -eq $ni.ContextMenuStrip) { return }

    $hotkeyDisplay = Get-HotkeyDisplayString
    # The hotkey display item is at index 2 (after Show and separator)
    $items = $ni.ContextMenuStrip.Items
    if ($items.Count -ge 3) {
        $items[2].Text = "Hotkey: $hotkeyDisplay"
    }
}

function Invoke-TrayExit {
    $script:TrayState.ForceExit = $true
    Unregister-GlobalHotkey
    Remove-TrayIcon

    $w = $script:TrayState.Window
    if ($null -ne $w) {
        $w.Dispatcher.Invoke([Action] {
                $w.Close()
                # Shut down the WPF Application so Application.Run() exits
                if ($null -ne [System.Windows.Application]::Current) {
                    [System.Windows.Application]::Current.Shutdown()
                }
            })
    }
}

function Remove-TrayIcon {
    $ni = $script:TrayState.NotifyIcon
    if ($null -ne $ni) {
        $ni.Visible = $false
        $ni.Dispose()
        $script:TrayState.NotifyIcon = $null
    }
}

function Test-ForceExit {
    return $script:TrayState.ForceExit
}

# --- Startup Registration ---

function Get-StartupShortcutPath {
    return Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\ProjectManager.lnk"
}

function Test-StartupRegistered {
    return (Test-Path (Get-StartupShortcutPath))
}

function Register-Startup {
    $shortcutPath = Get-StartupShortcutPath
    $targetPath = Join-Path $script:AppState.WorkspaceRoot "exec_project_manager.cmd"

    if (-not (Test-Path $targetPath)) { return $false }

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetPath
        $shortcut.WorkingDirectory = $script:AppState.WorkspaceRoot
        $shortcut.Description = "Project Manager"
        $shortcut.WindowStyle = 7  # Minimized
        $shortcut.Save()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Unregister-Startup {
    $shortcutPath = Get-StartupShortcutPath
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        return $true
    }
    return $false
}
