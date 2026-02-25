# XamlBuilder.ps1 - Main window XAML construction
# Builds the complete XAML string for the Project Manager window

function Build-MainWindowXaml {
    $styles = Get-ThemeResourcesXaml

    # Tab indices: 0=Dashboard, 1=Editor, 2=Setup, 3=AI Context, 4=Check, 5=Archive, 6=Convert
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Project Manager" Height="800" Width="1150"
        MinHeight="600" MinWidth="900"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip"
        WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Foreground="#cdd6f4">
    <Window.Resources>
$styles
    </Window.Resources>

    <Border Background="#1e1e2e" BorderBrush="#45475a" BorderThickness="1" CornerRadius="8">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="36"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="28"/>
            </Grid.RowDefinitions>

            <!-- ===== Title Bar ===== -->
            <Grid Grid.Row="0" Background="#181825" x:Name="titleBar">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal"
                            Margin="12,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="&#x25C8;" Foreground="#cba6f7" FontSize="14"
                               Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock Text="Project Manager" Foreground="#a6adc8"
                               FontSize="12" VerticalAlignment="Center"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal">
                    <Button x:Name="btnMinimize" Content="&#x2500;" FontSize="12"
                            Foreground="#a6adc8" Style="{StaticResource TitleBarButton}"/>
                    <Button x:Name="btnMaximize" Content="&#x25A1;" FontSize="13"
                            Foreground="#a6adc8" Style="{StaticResource TitleBarButton}"/>
                    <Button x:Name="btnClose"    Content="&#x2715;" FontSize="12"
                            Foreground="#a6adc8" Style="{StaticResource TitleBarCloseButton}"/>
                </StackPanel>
            </Grid>

            <!-- ===== Tab Control ===== -->
            <TabControl Grid.Row="1" x:Name="tabMain" BorderBrush="#45475a" Margin="8,8,8,0">

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
                                <ColumnDefinition Width="200"/>
                            </Grid.ColumnDefinitions>
                            <Button x:Name="btnDashRefresh" Content="Refresh"
                                    Grid.Column="0" Style="{StaticResource SmallButton}" Margin="0,0,8,0"/>
                            <TextBlock Grid.Column="2" Text="Filter: " VerticalAlignment="Center"
                                       Foreground="#a6adc8" Margin="0,0,4,0" FontSize="12"/>
                            <TextBox x:Name="txtDashFilter" Grid.Column="3" FontSize="12" Padding="6,4"/>
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
                                       Foreground="#a6adc8" Margin="0,0,4,0" FontSize="12"/>
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
                                           Foreground="#6c7086" FontSize="11"
                                           Margin="4,0,0,4"/>
                                <TreeView x:Name="editorFileTree" Grid.Row="1" Margin="0,0,0,4"
                                          MinHeight="80"/>
                                <TextBlock Grid.Row="2" Text="Workspace Files"
                                           Foreground="#6c7086" FontSize="11"
                                           Margin="4,4,0,4"/>
                                <TreeView x:Name="editorWorkspaceTree" Grid.Row="3" MinHeight="80"/>
                            </Grid>

                            <!-- Splitter -->
                            <GridSplitter Grid.Column="1" Width="5" HorizontalAlignment="Stretch"
                                          Background="#45475a" ShowsPreview="True">
                                <GridSplitter.Template>
                                    <ControlTemplate TargetType="GridSplitter">
                                        <Border Background="{TemplateBinding Background}"/>
                                    </ControlTemplate>
                                </GridSplitter.Template>
                            </GridSplitter>

                            <!-- Text editor (AvalonEdit host) -->
                            <Border Grid.Column="2" Background="#181825" CornerRadius="4"
                                    BorderBrush="#313244" BorderThickness="1">
                                <ContentControl x:Name="editorHost" />
                            </Border>
                        </Grid>

                        <!-- Bottom bar -->
                        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,8,0,0">
                            <Button x:Name="btnEditorSave" Content="Save (Ctrl+S)"
                                    Style="{StaticResource SmallButton}"
                                    Margin="0,0,8,0" IsEnabled="False"/>
                            <Button x:Name="btnEditorReload" Content="Reload"
                                    Style="{StaticResource SmallButton}"
                                    IsEnabled="False"/>
                        </StackPanel>
                    </Grid>
                </TabItem>

                <!-- Tab 2: Setup -->
                <TabItem Header="Setup">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>

                        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="300">
                            <StackPanel Margin="16">
                                <Label Content="Project Name (required)"/>
                                <TextBox x:Name="setupProjectName"/>

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
                                    <Button x:Name="btnSetupBrowseExternalShared" Grid.Column="1" Content="Add..." Width="40" Height="22" VerticalAlignment="Top" Background="#313244" Foreground="#cdd6f4" BorderBrush="#45475a"/>
                                </Grid>
                                <Button x:Name="btnSetup" Content="Run Setup"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="#a6adc8"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnSetupClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="#6c7086"
                                    BorderBrush="#45475a" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="#181825" CornerRadius="6"
                                BorderBrush="#313244" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtSetupOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="#a6e3a1" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 3: AI Context Setup -->
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
                                <Button x:Name="btnCtxLayer" Content="Run Context Layer Setup"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="#a6adc8"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnCtxClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="#6c7086"
                                    BorderBrush="#45475a" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="#181825" CornerRadius="6"
                                BorderBrush="#313244" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtCtxOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="#a6e3a1" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 4: Check -->
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
                                <Button x:Name="btnCheck" Content="Run Check"
                                        Style="{StaticResource RunButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="#a6adc8"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnCheckClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="#6c7086"
                                    BorderBrush="#45475a" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="#181825" CornerRadius="6"
                                BorderBrush="#313244" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtCheckOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="#a6e3a1" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 5: Archive -->
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
                                <CheckBox x:Name="archiveDryRun"
                                          Content="Dry Run (preview only, no changes)"
                                          IsChecked="True" Margin="0,6,0,0"/>
                                <Button x:Name="btnArchive" Content="Run Archive"
                                        Style="{StaticResource DangerButton}"/>
                            </StackPanel>
                        </ScrollViewer>

                        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="16,8,16,4">
                            <TextBlock Text="Output" FontSize="12" Foreground="#a6adc8"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnArchiveClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="#6c7086"
                                    BorderBrush="#45475a" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="#181825" CornerRadius="6"
                                BorderBrush="#313244" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtArchiveOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="#a6e3a1" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- Tab 6: Convert Tier -->
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
                            <TextBlock Text="Output" FontSize="12" Foreground="#a6adc8"
                                       VerticalAlignment="Center"/>
                            <Button x:Name="btnConvertClear" Content="Clear"
                                    Margin="10,0,0,0" Padding="8,3"
                                    Background="Transparent" Foreground="#6c7086"
                                    BorderBrush="#45475a" BorderThickness="1"
                                    Cursor="Hand" FontSize="11"/>
                        </StackPanel>
                        <Border Grid.Row="2" Background="#181825" CornerRadius="6"
                                BorderBrush="#313244" BorderThickness="1" Margin="16,0,16,16">
                            <TextBox x:Name="txtConvertOutput" IsReadOnly="True" TextWrapping="Wrap"
                                     VerticalScrollBarVisibility="Auto" Background="Transparent"
                                     Foreground="#a6e3a1" FontFamily="Consolas" FontSize="12"
                                     BorderThickness="0" Padding="10" AcceptsReturn="True"/>
                        </Border>
                    </Grid>
                </TabItem>

            </TabControl>

            <!-- ===== Status Bar ===== -->
            <Border Grid.Row="2" Background="#181825" BorderBrush="#45475a" BorderThickness="0,1,0,0">
                <Grid Margin="12,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock x:Name="statusProject" Grid.Column="0" Text="Ready"
                               Foreground="#6c7086" FontSize="11" VerticalAlignment="Center"/>
                    <TextBlock x:Name="statusFile" Grid.Column="1" Text=""
                               Foreground="#6c7086" FontSize="11" VerticalAlignment="Center"
                               Margin="16,0"/>
                    <TextBlock x:Name="statusEncoding" Grid.Column="2" Text=""
                               Foreground="#6c7086" FontSize="11" VerticalAlignment="Center"
                               Margin="0,0,16,0"/>
                    <TextBlock x:Name="statusDirty" Grid.Column="3" Text=""
                               Foreground="#f9e2af" FontSize="11" VerticalAlignment="Center"/>
                </Grid>
            </Border>

        </Grid>
    </Border>
</Window>
"@
}
