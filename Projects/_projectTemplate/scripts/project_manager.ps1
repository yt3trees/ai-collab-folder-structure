# project_manager.ps1 - Project Manager GUI entry point
# Usage: powershell -ExecutionPolicy Bypass -File project_manager.ps1
#        or double-click exec_project_manager.cmd

# Hide console window immediately (so only the WPF GUI is visible)
Add-Type -Name Win32 -Namespace Native -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$consoleWindow = [Native.Win32]::GetConsoleWindow()
if ($consoleWindow -ne [IntPtr]::Zero) {
    [Native.Win32]::ShowWindow($consoleWindow, 0) | Out-Null  # SW_HIDE
}

# --- Single instance check (prevent double launch) ---
$script:AppMutex = New-Object System.Threading.Mutex($false, "Global\ProjectManager_SingleInstance")
if (-not $script:AppMutex.WaitOne(0, $false)) {
    # Another instance is already running - exit silently
    $script:AppMutex.Dispose()
    exit 0
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic

$scriptDir = $PSScriptRoot
$managerDir = Join-Path $scriptDir "manager"

# Load AvalonEdit assembly for syntax-highlighted editor
$avalonEditDll = Join-Path $managerDir "lib\ICSharpCode.AvalonEdit.dll"
if (Test-Path $avalonEditDll) {
    Add-Type -Path $avalonEditDll
}
else {
    [System.Windows.MessageBox]::Show(
        "AvalonEdit DLL not found:`n$avalonEditDll",
        "Missing Dependency",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Warning
    ) | Out-Null
}

# --- Dot-source all modules ---
. "$managerDir\Config.ps1"
. "$managerDir\Theme.ps1"
. "$managerDir\ScriptRunner.ps1"
. "$managerDir\ProjectDiscovery.ps1"
. "$managerDir\EditorHelpers.ps1"
. "$managerDir\XamlBuilder.ps1"
. "$managerDir\TrayManager.ps1"
. "$managerDir\TabDashboard.ps1"
. "$managerDir\TabEditor.ps1"
. "$managerDir\TabSetup.ps1"
. "$managerDir\TabCheck.ps1"
. "$managerDir\TabArchive.ps1"
. "$managerDir\TabContextSetup.ps1"
. "$managerDir\TabConvert.ps1"
. "$managerDir\TabSettings.ps1"

# --- Initialize config and discover projects ---
Initialize-AppConfig -ScriptDir $scriptDir
$projectNameList = Get-ProjectNameList   # simple names for dropdowns

# --- Build XAML and create window ---
try {
    $xamlString = Build-MainWindowXaml
    [xml]$xaml = $xamlString
}
catch {
    [System.Windows.MessageBox]::Show(
        "Failed to parse XAML:`n$($_.Exception.Message)",
        "Startup Error",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    exit 1
}

$reader = New-Object System.Xml.XmlNodeReader $xaml
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    [System.Windows.MessageBox]::Show(
        "Failed to load XAML:`n$($_.Exception.Message)",
        "Startup Error",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    exit 1
}

# --- Tray mode: hide from taskbar ---
$window.ShowInTaskbar = $false

# --- Escape key: hide to tray ---
$window.Add_PreviewKeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
            $window.Hide()
            $_.Handled = $true
        }
    })

# --- Title bar controls ---
$titleBar = $window.FindName("titleBar")
$btnMaximize = $window.FindName("btnMaximize")
$btnClose = $window.FindName("btnClose")

$titleBar.Add_MouseLeftButtonDown({
        if ($_.ClickCount -eq 2) {
            if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                $window.WindowState = [System.Windows.WindowState]::Normal
            }
            else {
                $window.WindowState = [System.Windows.WindowState]::Maximized
            }
        }
        else {
            if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
                # Restore and reposition so cursor stays proportionally on the title bar
                $mousePos = [System.Windows.Input.Mouse]::GetPosition($window)
                $proportionalX = $mousePos.X / $window.ActualWidth

                $window.WindowState = [System.Windows.WindowState]::Normal

                # Force layout update
                $window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Render)

                $window.Left = $mousePos.X - ($window.ActualWidth * $proportionalX)
                $window.Top = 0
            }
            $window.DragMove()
        }
    })

$btnMaximize.Add_Click({
        if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
            $window.WindowState = [System.Windows.WindowState]::Normal
        }
        else {
            $window.WindowState = [System.Windows.WindowState]::Maximized
        }
    })

# Close button: hide to tray instead of closing (Shift+Click = force exit)
$btnClose.Add_Click({
        # Check if Shift is held for force exit
        $shiftHeld = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or
        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)

        if ($shiftHeld) {
            # Force exit: check for unsaved changes first
            if ($script:AppState.EditorState.IsDirty) {
                $fileName = [System.IO.Path]::GetFileName($script:AppState.EditorState.CurrentFile)
                $result = [System.Windows.MessageBox]::Show(
                    "Save changes to '$fileName' before closing?",
                    "Unsaved Changes",
                    [System.Windows.MessageBoxButton]::YesNoCancel,
                    [System.Windows.MessageBoxImage]::Warning
                )
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    Save-EditorFile -Window $window
                }
                elseif ($result -eq [System.Windows.MessageBoxResult]::Cancel) {
                    return
                }
            }
            Invoke-TrayExit
        }
        else {
            # Normal close: just hide to tray
            $window.Hide()
        }
    })

$window.Add_Closing({
        param($s, $e)
        # If not a force exit, cancel close and hide instead
        if (-not (Test-ForceExit)) {
            $e.Cancel = $true
            $s.Hide()
            return
        }

        # Force exit path: check for unsaved changes
        if ($script:AppState.EditorState.IsDirty) {
            $fileName = [System.IO.Path]::GetFileName($script:AppState.EditorState.CurrentFile)
            $result = [System.Windows.MessageBox]::Show(
                "Save changes to '$fileName' before closing?",
                "Unsaved Changes",
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Warning
            )
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Save-EditorFile -Window $s
            }
            elseif ($result -eq [System.Windows.MessageBoxResult]::Cancel) {
                $e.Cancel = $true
                $script:TrayState.ForceExit = $false
            }
        }
    })

# --- Initialize all tabs ---
Initialize-TabDashboard    -Window $window -ScriptDir $scriptDir
Initialize-TabEditor       -Window $window
Initialize-TabSetup        -Window $window -ScriptDir $scriptDir
Initialize-TabCheck        -Window $window -ScriptDir $scriptDir -ProjectList $projectNameList
Initialize-TabArchive      -Window $window -ScriptDir $scriptDir -ProjectList $projectNameList
Initialize-TabContextSetup -Window $window -ScriptDir $scriptDir -ProjectList $projectNameList
Initialize-TabConvert      -Window $window -ScriptDir $scriptDir -ProjectList $projectNameList
Initialize-TabSettings     -Window $window -ScriptDir $scriptDir

# --- Initialize system tray ---
Initialize-TrayIcon -Window $window

# --- Register hotkey after window is fully loaded ---
$window.Add_Loaded({
        # Register global hotkey (deferred to avoid message-processing race)
        Register-GlobalHotkey -Window $window | Out-Null
    })

# --- WPF Application lifecycle for tray-resident mode ---
# Use Application with OnExplicitShutdown so the app keeps running
# even when the main window is hidden
$app = [System.Windows.Application]::Current
if ($null -eq $app) {
    $app = New-Object System.Windows.Application
}
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown

# --- Show window with forced activation ---
$window.Show()
$window.Topmost = $true
$window.Activate()
$window.Topmost = $false

# Run the application loop (keeps running even when window is hidden)
$app.Run() | Out-Null

# --- Cleanup (after application exits) ---
Unregister-GlobalHotkey
Remove-TrayIcon
$script:AppMutex.ReleaseMutex()
$script:AppMutex.Dispose()
