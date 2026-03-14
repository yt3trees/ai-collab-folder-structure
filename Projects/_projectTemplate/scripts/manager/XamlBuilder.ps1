# XamlBuilder.ps1 - Main window XAML construction
# Builds the complete XAML string for the Project Manager window

function Build-MainWindowXaml {
    param([string]$ThemeName = "Default")

    $styles = Get-ThemeResourcesXaml -ThemeName $ThemeName
    $c = Get-ThemeColors -ThemeName $ThemeName

    # Tab indices: 0=Dashboard, 1=Editor, 2=Timeline, 3=Setup, 4=AI Context, 5=Check, 6=Archive, 7=Convert, 8=Asana Sync, 9=Settings
    $xamlTemplate = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Project Manager" Height="800" Width="1150"
        MinHeight="600" MinWidth="900"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip"
        WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Foreground="{{Text}}">
    <Window.Resources>
{{Styles}}
    </Window.Resources>

    <Border Background="{{Base}}" BorderBrush="{{Surface1}}" BorderThickness="1" CornerRadius="8">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="36"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="28"/>
            </Grid.RowDefinitions>

            <!-- ===== Title Bar ===== -->
            <Grid Grid.Row="0" Background="{{Mantle}}" x:Name="titleBar">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal"
                            Margin="12,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="&#x25C8;" Foreground="{{Mauve}}" FontSize="14"
                               Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock Text="Project Manager" Foreground="{{Subtext0}}"
                               FontSize="12" VerticalAlignment="Center"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Button x:Name="btnMaximize" Content="&#x25A1;" FontSize="13"
                            Foreground="{{Subtext0}}" Style="{StaticResource TitleBarButton}"/>
                    <Button x:Name="btnClose"    Content="&#x2715;" FontSize="12"
                            Foreground="{{Subtext0}}" Style="{StaticResource TitleBarCloseButton}"/>
                </StackPanel>
            </Grid>

            <!-- ===== Tab Control ===== -->
            <TabControl Grid.Row="1" x:Name="tabMain" BorderBrush="{{Surface1}}" Margin="8,8,8,0">

                <!-- Tab 0: Dashboard -->
                <TabItem Header="Dashboard">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <!-- Toolbar -->
                        <Grid Grid.Row="0" Margin="0,4,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="200"/>
                            </Grid.ColumnDefinitions>
                            <Button x:Name="btnDashRefresh" Content="Refresh"
                                    Grid.Column="0" Style="{StaticResource SmallButton}" Margin="0,0,8,0"/>
                            <CheckBox x:Name="chkShowHidden" Grid.Column="2" Content="Show Hidden"
                                      Foreground="{{Subtext0}}" FontSize="12" VerticalAlignment="Center"
                                      Margin="0,0,16,0"/>
                            <TextBlock Grid.Column="3" Text="Filter: " VerticalAlignment="Center"
                                       Foreground="{{Subtext0}}" Margin="0,0,4,0" FontSize="12"/>
                            <TextBox x:Name="txtDashFilter" Grid.Column="4" FontSize="12" Padding="6,4"/>
                        </Grid>

                        <!-- Cards area -->
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"
                                      HorizontalScrollBarVisibility="Disabled">
                            <WrapPanel x:Name="dashboardCards" Orientation="Horizontal"
                                       Margin="0,0,0,8"/>
                        </ScrollViewer>
                    </Grid>
                </TabItem>

                <!-- Tab 1: Editor -->
                <TabItem Header="Editor">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Toolbar -->
                        <Grid Grid.Row="0" Margin="0,4,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Project: " VerticalAlignment="Center"
                                       Foreground="{{Subtext0}}" Margin="0,0,4,0" FontSize="12"/>
                            <ComboBox x:Name="editorProjectCombo" Grid.Column="1" Margin="0,0,8,0"/>
                             <Button x:Name="btnNewDecisionLog" Grid.Column="3"
                                     Content="+ Decision Log"
                                     Style="{StaticResource SmallButton}"/>
                        </Grid>

                        <!-- Split: Tree | Editor -->
                        <Grid Grid.Row="1">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="220" MinWidth="100" MaxWidth="400"/>
                                <ColumnDefinition Width="5"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- File tree panel -->
                            <Grid Grid.Column="0">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="Project Files"
                                           Foreground="{{Overlay0}}" FontSize="11"
                                           Margin="4,0,0,4"/>
                                <TreeView x:Name="editorFileTree" Grid.Row="1" Margin="0,0,0,4"
                                          MinHeight="80"/>
                                <TextBlock Grid.Row="2" Text="Workspace Files"
                                           Foreground="{{Overlay0}}" FontSize="11"
                                           Margin="4,4,0,4"/>
                                <TreeView x:Name="editorWorkspaceTree" Grid.Row="3" MinHeight="80"/>
                            </Grid>

                            <!-- Splitter -->
                            <GridSplitter Grid.Column="1" Width="5" HorizontalAlignment="Stretch"
                                          Background="{{Surface1}}" ShowsPreview="True">
                                <GridSplitter.Template>
                                    <ControlTemplate TargetType="GridSplitter">
                                        <Border Background="{TemplateBinding Background}"/>
                                    </ControlTemplate>
                                </GridSplitter.Template>
                            </GridSplitter>

                            <!-- Text editor (AvalonEdit host) -->
                            <Border Grid.Column="2" Background="{{Mantle}}" CornerRadius="4"
                                    BorderBrush="{{Surface0}}" BorderThickness="1">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>

                                    <Border x:Name="editorFindBar"
                                            Grid.Row="0"
                                            Background="{{Base}}"
                                            BorderBrush="{{Surface2}}"
                                            BorderThickness="0,0,0,1"
                                            Padding="8,6"
                                            Visibility="Collapsed">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBox x:Name="txtEditorFind"
                                                     Grid.Column="0"
                                                     Margin="0,0,8,0"
                                                     MinHeight="26"/>
                                            <Button x:Name="btnEditorFindPrev"
                                                    Grid.Column="1"
                                                    Content="&#x2190;"
                                                    Style="{StaticResource SmallButton}"
                                                    Margin="0,0,6,0"
                                                    MinWidth="34"/>
                                            <Button x:Name="btnEditorFindNext"
                                                    Grid.Column="2"
                                                    Content="&#x2192;"
                                                    Style="{StaticResource SmallButton}"
                                                    Margin="0,0,6,0"
                                                    MinWidth="34"/>
                                            <Button x:Name="btnEditorFindClose"
                                                    Grid.Column="3"
                                                    Content="&#x2715;"
                                                    Style="{StaticResource SmallButton}"
                                                    MinWidth="34"/>
                                        </Grid>
                                    </Border>

                                    <ContentControl x:Name="editorHost" Grid.Row="1"/>
                                </Grid>
                            </Border>
                        </Grid>

                        <!-- Bottom bar -->
                        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,8,0,0">
                            <Button x:Name="btnEditorSave" Content="Save (Ctrl+S)"
                                    Style="{StaticResource SmallButton}"
                                    Margin="0,0,8,0" IsEnabled="False"/>
                            <Button x:Name="btnEditorReload" Content="Reload"
                                    Style="{StaticResource SmallButton}"
                                    Margin="0,0,8,0" IsEnabled="False"/>
                            <Button x:Name="btnEditorDir" Content="Dir"
                                    Style="{StaticResource SmallButton}"
                                    Margin="0,0,8,0"/>
                            <Button x:Name="btnEditorTerm" Content="Term"
                                    Style="{StaticResource SmallButton}"
                                    Margin="0,0,8,0"/>
                            <Button x:Name="btnEditorResume" Content="Resume"
                                    Style="{StaticResource SmallButton}"/>
                        </StackPanel>
                    </Grid>
                </TabItem>

                <!-- Tab 2: Timeline -->
                <TabItem Header="Timeline">
                    <Grid Margin="8">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Toolbar -->
                        <Grid Grid.Row="0" Margin="0,4,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="200"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="timelineProjectLabel" Grid.Column="0" Text="Project: "
                                       VerticalAlignment="Center"
                                       Foreground="{{Subtext0}}" Margin="0,0,4,0" FontSize="12"/>
                            <ComboBox x:Name="timelineProjectCombo" Grid.Column="1" Margin="0,0,8,0"/>
                            <TextBlock Grid.Column="2" Text="Period: " VerticalAlignment="Center"
                                       Foreground="{{Subtext0}}" Margin="0,0,4,0" FontSize="12"/>
                            <ComboBox x:Name="timelinePeriodCombo" Grid.Column="3" Width="120">
                                <ComboBoxItem Content="30 days" IsSelected="True"/>
                                <ComboBoxItem Content="90 days"/>
                                <ComboBoxItem Content="All"/>
                            </ComboBox>
                            <Button x:Name="timelineViewList" Grid.Column="5" Content="List"
                                    Style="{StaticResource SmallButton}" Margin="4,0,2,0"/>
                            <Button x:Name="timelineViewHeatmap" Grid.Column="6" Content="Heatmap"
                                    Style="{StaticResource SmallButton}" Margin="2,0,0,0"/>
                        </Grid>

                        <!-- Timeline entries -->
                        <Border Grid.Row="1" Background="{{Mantle}}" CornerRadius="4"
                                BorderBrush="{{Surface0}}" BorderThickness="1">
                            <ScrollViewer VerticalScrollBarVisibility="Auto"
                                          HorizontalScrollBarVisibility="Auto">
                                <StackPanel>
                                    <StackPanel x:Name="timelineEntries" Margin="8"/>
                                    <StackPanel x:Name="timelineHeatmapPanel" Margin="8"
                                                Visibility="Collapsed"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <!-- Stats bar -->
                        <Border Grid.Row="2" Margin="0,8,0,0">
                            <StackPanel x:Name="timelineStats" Orientation="Horizontal">
                                <TextBlock x:Name="timelineStatText" Text="" FontSize="11"
                                           Foreground="{{Overlay0}}" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 3: Setup -->
                <TabItem Header="Setup">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="360">
                            <StackPanel Margin="16">
                                <Label Content="Project Name (required)"/>
                                <ComboBox x:Name="setupProjectName" IsEditable="True"/>

                                <Label Content="Tier"/>
                                <ComboBox x:Name="setupTier" SelectedIndex="0">
                                    <ComboBoxItem Content="full"/>
                                    <ComboBoxItem Content="mini"/>
                                </ComboBox>
                                <Label Content="Category"/>
                                <ComboBox x:Name="setupCategory" SelectedIndex="0">
                                    <ComboBoxItem Content="project"/>
                                    <ComboBoxItem Content="domain"/>
                                </ComboBox>
                                <Label Content="External Shared Folders (Optional, one path per line)"/>
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="setupExternalShared" Grid.Column="0" Margin="0,0,8,0"
                                             AcceptsReturn="True" TextWrapping="Wrap" MinHeight="44" MaxHeight="88"
                                             VerticalScrollBarVisibility="Auto"/>
                                    <Button x:Name="btnSetupBrowseExternalShared" Grid.Column="1" Content="Add..." Width="40" Height="22" VerticalAlignment="Top" Background="{{Surface0}}" Foreground="{{Text}}" BorderBrush="{{Surface1}}"/>
                                </Grid>
                                <CheckBox x:Name="setupAlsoContextLayer"
                                          Content="Also run AI Context Setup"
                                          IsChecked="True" Foreground="{{Subtext0}}" Margin="0,4,0,0"/>
                                <Button x:Name="btnSetup" Content="Run Setup"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnSetupClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtSetupOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 4: AI Context -->
                <TabItem Header="AI Context">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="200">
                            <StackPanel Margin="16">
                                <Label Content="Project Name (optional - blank for workspace-only)"/>
                                <ComboBox x:Name="ctxProjectCombo" IsEditable="True"/>
                                <CheckBox x:Name="ctxMini" Content="Mini tier project (-Mini)"
                                          Margin="0,10,0,0"/>
                                <CheckBox x:Name="ctxDomain" Content="Domain project (-Category domain)"
                                          Margin="0,6,0,0"/>
                                <CheckBox x:Name="ctxForce" Content="Overwrite existing skills (-Force)"
                                          Margin="0,6,0,0"/>
                                <Button x:Name="btnCtxLayer" Content="Run Context Layer Setup"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnCtxClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtCtxOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 5: Check -->
                <TabItem Header="Check">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="200">
                            <StackPanel Margin="16">
                                <Label Content="Project Name"/>
                                <ComboBox x:Name="checkProjectCombo" IsEditable="True"/>
                                <CheckBox x:Name="checkMini" Content="Mini tier project (-Mini)"
                                          Margin="0,10,0,0"/>
                                <CheckBox x:Name="checkDomain" Content="Domain project (-Category domain)"
                                          Margin="0,6,0,0"/>
                                <Button x:Name="btnCheck" Content="Run Check"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnCheckClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtCheckOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 6: Archive -->
                <TabItem Header="Archive">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="240">
                            <StackPanel Margin="16">
                                <Label Content="Project Name"/>
                                <ComboBox x:Name="archiveProjectCombo" IsEditable="True"/>
                                <CheckBox x:Name="archiveMini" Content="Mini tier project (-Mini)"
                                          Margin="0,10,0,0"/>
                                <CheckBox x:Name="archiveDomain" Content="Domain project (-Category domain)"
                                          Margin="0,6,0,0"/>
                                <CheckBox x:Name="archiveDryRun"
                                          Content="Dry Run (preview only, no changes)"
                                          IsChecked="True" Margin="0,6,0,0"/>
                                <Button x:Name="btnArchive" Content="Run Archive"
                                        Style="{StaticResource DangerButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnArchiveClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtArchiveOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 7: Convert Tier -->
                <TabItem Header="Convert">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="280">
                            <StackPanel Margin="16">
                                <Label Content="Project Name"/>
                                <ComboBox x:Name="convertProjectCombo" IsEditable="True"/>
                                <Label Content="Convert To"/>
                                <ComboBox x:Name="convertToTier" SelectedIndex="0">
                                    <ComboBoxItem Content="full"/>
                                    <ComboBoxItem Content="mini"/>
                                </ComboBox>

                                <CheckBox x:Name="convertDryRun"
                                          Content="Dry Run (preview only, no changes)"
                                          IsChecked="True" Margin="0,10,0,0"/>
                                <Button x:Name="btnConvert" Content="Run Convert"
                                        Style="{StaticResource DangerButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnConvertClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtConvertOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 8: Asana Sync -->
                <TabItem Header="Asana Sync">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="420">
                            <StackPanel Margin="16">
                                <TextBlock Text="Manual Execution" Foreground="{{Mauve}}" FontSize="15"
                                           FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <Button x:Name="btnAsanaSync" Content="Run Sync Now"
                                        Style="{StaticResource RunButton}"/>

                                <TextBlock Text="Scheduled Execution" Foreground="{{Mauve}}" FontSize="15"
                                           FontWeight="SemiBold" Margin="0,20,0,8"/>
                                <CheckBox x:Name="chkAsanaSchedule"
                                          Content="Enable scheduled sync"
                                          Margin="0,0,0,8"/>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                    <TextBlock Text="Interval (min): " Foreground="{{Subtext0}}" FontSize="13"
                                               VerticalAlignment="Center"/>
                                    <TextBox x:Name="txtAsanaInterval" Text="60" Width="80"
                                             HorizontalAlignment="Left"/>
                                </StackPanel>

                                <Button x:Name="btnAsanaSaveSchedule" Content="Save Schedule"
                                        Padding="12,4" Background="{{Surface1}}" Foreground="{{Text}}"
                                        BorderBrush="{{Surface2}}" BorderThickness="1" Cursor="Hand"
                                        FontSize="12" HorizontalAlignment="Left" Margin="0,0,0,12"/>

                                <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                                    <TextBlock Text="Last Sync: " Foreground="{{Subtext0}}" FontSize="13"
                                               VerticalAlignment="Center"/>
                                    <TextBlock x:Name="lblAsanaLastSync" Text="---" Foreground="{{Green}}"
                                               FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>

                                <!-- asana_config.json editor -->
                                <TextBlock Text="Project asana_config.json" Foreground="{{Mauve}}" FontSize="15"
                                           FontWeight="SemiBold" Margin="0,20,0,8"/>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                    <ComboBox x:Name="cmbAsanaConfigProject" Width="260" HorizontalAlignment="Left"/>
                                    <Button x:Name="btnAsanaConfigLoad" Content="Load"
                                            Margin="8,0,0,0" Padding="10,4"
                                            Background="{{Surface1}}" Foreground="{{Text}}"
                                            BorderBrush="{{Surface2}}" BorderThickness="1"
                                            Cursor="Hand" FontSize="12"/>
                                </StackPanel>
                                <TextBlock Text="Asana Project GIDs (one per line):" Foreground="{{Subtext0}}"
                                           FontSize="12" Margin="0,0,0,3"/>
                                <TextBox x:Name="txtAsanaConfigGids" Height="64" AcceptsReturn="True"
                                         TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto"
                                         FontFamily="Consolas" FontSize="12" Padding="6,4" Margin="0,0,0,8"/>
                                <TextBlock Text="Anken Aliases (optional, one per line):" Foreground="{{Subtext0}}"
                                           FontSize="12" Margin="0,0,0,3"/>
                                <TextBox x:Name="txtAsanaConfigAliases" Height="48" AcceptsReturn="True"
                                         TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto"
                                         FontFamily="Consolas" FontSize="12" Padding="6,4" Margin="0,0,0,8"/>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                    <Button x:Name="btnAsanaConfigSave" Content="Save Config"
                                            Padding="12,4" Background="{{Surface1}}" Foreground="{{Text}}"
                                            BorderBrush="{{Surface2}}" BorderThickness="1"
                                            Cursor="Hand" FontSize="12" HorizontalAlignment="Left"/>
                                    <TextBlock x:Name="lblAsanaConfigStatus" Text="" Foreground="{{Green}}"
                                               FontSize="12" VerticalAlignment="Center" Margin="12,0,0,0"/>
                                </StackPanel>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnAsanaClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtAsanaOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 9: Settings -->
                <TabItem Header="Settings">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="360">
                            <StackPanel Margin="16">
                                <!-- Theme Selection -->
                                <TextBlock Text="Appearance" Foreground="{{Mauve}}" FontSize="15"
                                           FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <Label Content="Color Theme"/>
                                <ComboBox x:Name="settingsThemeCombo" Width="200" HorizontalAlignment="Left" Margin="0,0,0,16">
                                    <ComboBoxItem Content="Default"/>
                                    <ComboBoxItem Content="GitHub"/>
                                </ComboBox>

                                <!-- Global Hotkey -->
                                <TextBlock Text="Global Hotkey" Foreground="{{Mauve}}" FontSize="15"
                                           FontWeight="SemiBold" Margin="0,0,0,8"/>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
                                    <TextBlock Text="Current: " Foreground="{{Subtext0}}" FontSize="13"
                                               VerticalAlignment="Center"/>
                                    <TextBlock x:Name="settingsCurrentHotkey" Text="..." Foreground="{{Green}}"
                                               FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>

                                <!-- Modifier Keys -->
                                <Label Content="Modifier Keys"/>
                                <WrapPanel Margin="0,0,0,8">
                                    <CheckBox x:Name="settingsModCtrl" Content="Ctrl" Margin="0,0,16,0"/>
                                    <CheckBox x:Name="settingsModShift" Content="Shift" Margin="0,0,16,0"/>
                                    <CheckBox x:Name="settingsModAlt" Content="Alt" Margin="0,0,16,0"/>
                                    <CheckBox x:Name="settingsModWin" Content="Win" Margin="0,0,16,0"/>
                                </WrapPanel>

                                <!-- Key -->
                                <Label Content="Key (A-Z, 0-9, F1-F12)"/>
                                <TextBox x:Name="settingsKeyInput" Width="100" HorizontalAlignment="Left"
                                         MaxLength="5"/>

                                <!-- Startup -->
                                <TextBlock Text="Startup" Foreground="{{Mauve}}" FontSize="15"
                                           FontWeight="SemiBold" Margin="0,20,0,8"/>
                                <CheckBox x:Name="settingsStartup"
                                          Content="Launch at Windows startup"
                                          Margin="0,0,0,4"/>

                                <Button x:Name="btnSettingsSave" Content="Save Settings"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="{{Subtext0}}"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnSettingsClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="{{Overlay0}}"
                                    BorderBrush="{{Surface1}}" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="{{Mantle}}" CornerRadius="6"
                                BorderBrush="{{Surface0}}" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtSettingsOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="{{Green}}" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

            </TabControl>

            <!-- ===== Command Palette Overlay ===== -->
            <Border x:Name="cmdPaletteOverlay" Grid.Row="1"
                    Background="#CC{{BaseWithoutHash}}" Visibility="Collapsed"
                    Panel.ZIndex="100">
                <Border Background="{{Surface0}}" BorderBrush="{{Mauve}}" BorderThickness="1"
                        CornerRadius="8" Padding="0"
                        VerticalAlignment="Top" MaxWidth="600" MaxHeight="500"
                        HorizontalAlignment="Center" Margin="0,40,0,0">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <TextBox x:Name="cmdPaletteInput" Grid.Row="0"
                                 FontSize="16" Padding="12,10"
                                 Background="{{Base}}" Foreground="{{Text}}"
                                 BorderThickness="0,0,0,1" BorderBrush="{{Surface1}}"
                                 CaretBrush="{{Text}}"/>
                        <ListBox x:Name="cmdPaletteList" Grid.Row="1"
                                 Background="Transparent" BorderThickness="0"
                                 Foreground="{{Text}}" MaxHeight="400"
                                 ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
                    </Grid>
                </Border>
            </Border>

            <!-- ===== Status Bar ===== -->
            <Border Grid.Row="2" Background="{{Mantle}}" BorderBrush="{{Surface1}}" BorderThickness="0,1,0,0">
                <Grid Margin="12,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock x:Name="statusProject" Grid.Column="0" Text="Ready"
                               Foreground="{{Overlay0}}" FontSize="11" VerticalAlignment="Center"/>
                    <TextBlock x:Name="statusFile" Grid.Column="1" Text=""
                               Foreground="{{Overlay0}}" FontSize="11" VerticalAlignment="Center"
                               Margin="16,0"/>
                    <TextBlock x:Name="statusHealth" Grid.Column="2" Text=""
                               Foreground="{{Overlay0}}" FontSize="11" VerticalAlignment="Center"
                               Margin="0,0,16,0"/>
                    <TextBlock x:Name="statusEncoding" Grid.Column="3" Text=""
                               Foreground="{{Overlay0}}" FontSize="11" VerticalAlignment="Center"
                               Margin="0,0,16,0"/>
                    <TextBlock x:Name="statusDirty" Grid.Column="4" Text=""
                               Foreground="{{Yellow}}" FontSize="11" VerticalAlignment="Center"/>
                </Grid>
            </Border>

        </Grid>
    </Border>
</Window>
'@

    # Replacement
    $xaml = $xamlTemplate.Replace("{{Styles}}", $styles)
    foreach ($key in $c.Keys) {
        $xaml = $xaml.Replace("{{$key}}", $c[$key])
    }
    
    # Handle specific key for transparent overlay
    $baseWithoutHash = $c.Base.TrimStart('#')
    $xaml = $xaml.Replace("{{BaseWithoutHash}}", $baseWithoutHash)

    return $xaml
}
