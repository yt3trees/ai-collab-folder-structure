# Project Template GUI Launcher
# WPF-based GUI for running setup, check, and archive scripts
# Usage: Right-click -> "Run with PowerShell" or: powershell -ExecutionPolicy Bypass -File project_launcher.ps1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# --- Detect existing projects ---
$scriptDir = $PSScriptRoot
$workspaceRoot = Split-Path (Split-Path $scriptDir)

function Get-ExistingProjects {
    $projects = @()
    # Regular projects
    $dirs = Get-ChildItem -Path $workspaceRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^[_\.]' -and $_.Name -ne 'test' }
    foreach ($d in $dirs) { $projects += $d.Name }
    # Support projects
    $supportDir = Join-Path $workspaceRoot "_mini"
    if (Test-Path $supportDir) {
        $sDirs = Get-ChildItem -Path $supportDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^[_\.]' }
        foreach ($d in $sDirs) { $projects += "[Mini] $($d.Name)" }
    }
    return ($projects | Sort-Object)
}

$existingProjects = Get-ExistingProjects

# --- XAML UI Definition ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Project Template Launcher" Height="700" Width="650"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip"
        Background="#1e1e2e" Foreground="#cdd6f4">
    <Window.Resources>
        <!-- Dark Theme Styles -->
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="#1e1e2e"/>
            <Setter Property="BorderBrush" Value="#45475a"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Foreground" Value="#bac2de"/>
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="BorderBrush" Value="#45475a"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="tabBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1,1,1,0"
                                CornerRadius="6,6,0,0" Padding="{TemplateBinding Padding}" Margin="2,0,0,0">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="tabBorder" Property="Background" Value="#45475a"/>
                                <Setter Property="Foreground" Value="#cba6f7"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="tabBorder" Property="Background" Value="#585b70"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,6,0,2"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="BorderBrush" Value="#585b70"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#cdd6f4"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="BorderBrush" Value="#585b70"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="toggleButton" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}"
                                                BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="1" CornerRadius="0">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition/>
                                                    <ColumnDefinition Width="20"/>
                                                </Grid.ColumnDefinitions>
                                                <Path Grid.Column="1" Data="M0,0 L4,4 8,0" Stroke="#cdd6f4"
                                                      StrokeThickness="1.5" HorizontalAlignment="Center"
                                                      VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                                <ToggleButton.Background>
                                    <SolidColorBrush Color="#313244"/>
                                </ToggleButton.Background>
                                <ToggleButton.BorderBrush>
                                    <SolidColorBrush Color="#585b70"/>
                                </ToggleButton.BorderBrush>
                            </ToggleButton>
                            <ContentPresenter x:Name="contentPresenter"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="10,6,28,6" VerticalAlignment="Center"
                                              HorizontalAlignment="Left" IsHitTestVisible="False"/>
                            <TextBox x:Name="PART_EditableTextBox" Visibility="Collapsed"
                                     Background="Transparent" Foreground="#cdd6f4"
                                     CaretBrush="#cdd6f4" FontSize="13"
                                     Margin="8,4,28,4" VerticalAlignment="Center"
                                     HorizontalAlignment="Stretch" Focusable="True"
                                     IsReadOnly="{TemplateBinding IsReadOnly}"/>
                            <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   Placement="Bottom" AllowsTransparency="True" Focusable="False"
                                   PopupAnimation="Slide">
                                <Border Background="#313244" BorderBrush="#585b70" BorderThickness="1"
                                        MaxHeight="{TemplateBinding MaxDropDownHeight}"
                                        MinWidth="{TemplateBinding ActualWidth}">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEditable" Value="True">
                                <Setter TargetName="PART_EditableTextBox" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="contentPresenter" Property="Visibility" Value="Collapsed"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="itemBorder" Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="itemBorder" Property="Background" Value="#585b70"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#cdd6f4"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,6,0,2"/>
        </Style>
        <Style x:Key="RunButton" TargetType="Button">
            <Setter Property="Background" Value="#cba6f7"/>
            <Setter Property="Foreground" Value="#1e1e2e"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="Margin" Value="0,12,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="btnBorder" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="btnBorder" Property="Background" Value="#b4befe"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="btnBorder" Property="Background" Value="#585b70"/>
                                <Setter Property="Foreground" Value="#6c7086"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button">
            <Setter Property="Background" Value="#f38ba8"/>
            <Setter Property="Foreground" Value="#1e1e2e"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="Margin" Value="0,12,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="btnBorder" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="btnBorder" Property="Background" Value="#eba0ac"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="btnBorder" Property="Background" Value="#585b70"/>
                                <Setter Property="Foreground" Value="#6c7086"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="200"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,12">
            <TextBlock Text="Project Template Launcher" FontSize="22" FontWeight="Bold"
                       Foreground="#cba6f7" Margin="0,0,0,4"/>
            <TextBlock Text="Setup / Check / Archive projects" FontSize="12" Foreground="#6c7086"/>
        </StackPanel>

        <!-- Tabs -->
        <TabControl Grid.Row="1" x:Name="tabMain" BorderBrush="#45475a">
            <!-- Setup Tab -->
            <TabItem Header="Setup">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="16">
                        <Label Content="Project Name (required)"/>
                        <TextBox x:Name="setupProjectName"/>

                        <Label Content="Structure"/>
                        <ComboBox x:Name="setupStructure" SelectedIndex="0">
                            <ComboBoxItem Content="new"/>
                            <ComboBoxItem Content="legacy"/>
                        </ComboBox>

                        <Label Content="Tier"/>
                        <ComboBox x:Name="setupTier" SelectedIndex="0">
                            <ComboBoxItem Content="full"/>
                            <ComboBoxItem Content="mini"/>
                        </ComboBox>

                        <Button x:Name="btnSetup" Content="Run Setup" Style="{StaticResource RunButton}"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Check Tab -->
            <TabItem Header="Check">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="16">
                        <Label Content="Project Name"/>
                        <ComboBox x:Name="checkProjectCombo" IsEditable="True" />

                        <CheckBox x:Name="checkSupport" Content="Mini tier project (-Mini)" Margin="0,10,0,0"/>

                        <Button x:Name="btnCheck" Content="Run Check" Style="{StaticResource RunButton}"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Archive Tab -->
            <TabItem Header="Archive">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="16">
                        <Label Content="Project Name"/>
                        <ComboBox x:Name="archiveProjectCombo" IsEditable="True" />

                        <CheckBox x:Name="archiveSupport" Content="Mini tier project (-Mini)" Margin="0,10,0,0"/>
                        <CheckBox x:Name="archiveDryRun" Content="Dry Run (preview only, no changes)" IsChecked="True" Margin="0,6,0,0"/>

                        <Button x:Name="btnArchive" Content="Run Archive" Style="{StaticResource DangerButton}"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- Output Header -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,10,0,4">
            <TextBlock Text="Output" FontSize="13" Foreground="#a6adc8" VerticalAlignment="Center"/>
            <Button x:Name="btnClear" Content="Clear" Margin="12,0,0,0" Padding="10,3"
                    Background="Transparent" Foreground="#6c7086" BorderBrush="#45475a"
                    BorderThickness="1" Cursor="Hand" FontSize="11"/>
        </StackPanel>

        <!-- Output Area -->
        <Border Grid.Row="3" Background="#181825" CornerRadius="6" BorderBrush="#313244" BorderThickness="1">
            <TextBox x:Name="txtOutput" IsReadOnly="True" TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                     Foreground="#a6e3a1" FontFamily="Consolas" FontSize="12"
                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
        </Border>
    </Grid>
</Window>
"@

# --- Create Window ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Get Controls ---
$setupProjectName    = $window.FindName("setupProjectName")
$setupStructure      = $window.FindName("setupStructure")
$setupTier           = $window.FindName("setupTier")
$btnSetup            = $window.FindName("btnSetup")

$checkProjectCombo   = $window.FindName("checkProjectCombo")
$checkSupport        = $window.FindName("checkSupport")
$btnCheck            = $window.FindName("btnCheck")

$archiveProjectCombo = $window.FindName("archiveProjectCombo")
$archiveSupport      = $window.FindName("archiveSupport")
$archiveDryRun       = $window.FindName("archiveDryRun")
$archiveForce        = $window.FindName("archiveForce")
$btnArchive          = $window.FindName("btnArchive")

$txtOutput           = $window.FindName("txtOutput")
$btnClear            = $window.FindName("btnClear")

# --- Populate project dropdowns ---
foreach ($proj in $existingProjects) {
    $checkProjectCombo.Items.Add($proj) | Out-Null
    $archiveProjectCombo.Items.Add($proj) | Out-Null
}

# --- Helper: Parse project name from combo selection ---
function Get-ProjectParams {
    param([string]$ComboText, [bool]$SupportChecked)

    $name = $ComboText.Trim()
    $isSupport = $SupportChecked

    # Auto-detect [Support] prefix
    if ($name -match '^\[Mini\]\s+(.+)$') {
        $name = $Matches[1]
        $isSupport = $true
    }

    return @{ Name = $name; IsSupport = $isSupport }
}

# --- Helper: Run a script and capture output ---
function Invoke-ScriptWithOutput {
    param([string]$ScriptPath, [string]$ArgumentString)

    $txtOutput.Text = ""
    $txtOutput.Text += ">>> $ScriptPath $ArgumentString`r`n"
    $txtOutput.Text += "---`r`n"

    # Force UI update
    $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

    try {
        # Run as subprocess to capture Write-Host output
        $cmd = "& '$ScriptPath' $ArgumentString"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($stdout) { $txtOutput.Text += $stdout }
        if ($stderr) { $txtOutput.Text += $stderr }
    }
    catch {
        $txtOutput.Text += "`r`n[ERROR] $($_.Exception.Message)`r`n"
    }

    $txtOutput.Text += "`r`n--- Done ---`r`n"
    $txtOutput.ScrollToEnd()
}

# --- Event Handlers ---

# Setup button
$btnSetup.Add_Click({
    $name = $setupProjectName.Text.Trim()
    if ([string]::IsNullOrEmpty($name)) {
        [System.Windows.MessageBox]::Show("Project Name is required.", "Validation",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $structure = ($setupStructure.SelectedItem).Content
    $tier = ($setupTier.SelectedItem).Content

    $argStr = "-ProjectName '$name' -Structure $structure -Tier $tier"
    $scriptPath = Join-Path $scriptDir "setup_project.ps1"
    Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr
})

# Check button
$btnCheck.Add_Click({
    $params = Get-ProjectParams -ComboText $checkProjectCombo.Text -SupportChecked $checkSupport.IsChecked
    if ([string]::IsNullOrEmpty($params.Name)) {
        [System.Windows.MessageBox]::Show("Project Name is required.", "Validation",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $argStr = "-ProjectName '$($params.Name)'"
    if ($params.IsSupport) { $argStr += " -Mini" }

    $scriptPath = Join-Path $scriptDir "check_project.ps1"
    Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr
})

# Archive button
$btnArchive.Add_Click({
    $params = Get-ProjectParams -ComboText $archiveProjectCombo.Text -SupportChecked $archiveSupport.IsChecked
    if ([string]::IsNullOrEmpty($params.Name)) {
        [System.Windows.MessageBox]::Show("Project Name is required.", "Validation",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Confirm if not DryRun
    if (-not $archiveDryRun.IsChecked) {
        $result = [System.Windows.MessageBox]::Show(
            "Archive '$($params.Name)' for real (not DryRun)?`nThis will move project folders to _archive/.",
            "Confirm Archive",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    $argStr = "-ProjectName '$($params.Name)' -Force"
    if ($params.IsSupport) { $argStr += " -Mini" }
    if ($archiveDryRun.IsChecked) { $argStr += " -DryRun" }

    $scriptPath = Join-Path $scriptDir "archive_project.ps1"
    Invoke-ScriptWithOutput -ScriptPath $scriptPath -ArgumentString $argStr
})

# Clear output
$btnClear.Add_Click({
    $txtOutput.Text = ""
})

# --- Show Window ---
$window.ShowDialog() | Out-Null
