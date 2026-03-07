# Theme.ps1 - Customizable theme XAML style definitions
# Supports "Default" (Catppuccin Mocha) and "GitHub" (GitHub Dark)

function Get-ThemeResourcesXaml {
    param([string]$ThemeName = "Default")

    $themes = @{
        "Default" = @{
            Base      = "#1e1e2e"; Mantle = "#181825"; Crust = "#11111b"
            Text      = "#cdd6f4"; Subtext0 = "#a6adc8"; Subtext1 = "#bac2de"
            Surface0  = "#313244"; Surface1 = "#45475a"; Surface2 = "#585b70"
            Overlay0  = "#6c7086"; Overlay1 = "#7f849c"; Overlay2 = "#9399b2"
            Blue      = "#89b4fa"; Lavender = "#b4befe"; Sapphire = "#74c7ec"; Sky = "#89dceb"
            Mauve     = "#cba6f7"; Pink = "#f5c2e7"; Flamingo = "#f2cdcd"; Rosewater = "#f5e0dc"
            Red       = "#f38ba8"; Peach = "#fab387"; Yellow = "#f9e2af"; Green = "#a6e3a1"
            Teal      = "#94e2d5"; Maroon = "#eba0ac"
        }
        "GitHub" = @{
            Base      = "#0d1117"; Mantle = "#010409"; Crust = "#010409"
            Text      = "#c9d1d9"; Subtext0 = "#8b949e"; Subtext1 = "#b1bac4"
            Surface0  = "#161b22"; Surface1 = "#30363d"; Surface2 = "#484f58"
            Overlay0  = "#6e7681"; Overlay1 = "#8b949e"; Overlay2 = "#b1bac4"
            Blue      = "#58a6ff"; Lavender = "#a5d6ff"; Sapphire = "#388bfd"; Sky = "#79c0ff"
            Mauve     = "#58a6ff"; Pink = "#ff7b72"; Flamingo = "#ffa198"; Rosewater = "#ff7b72"
            Red       = "#f85149"; Peach = "#ffa657"; Yellow = "#e3b341"; Green = "#7ee787"
            Teal      = "#7ee787"; Maroon = "#f85149"
        }
    }

    $c = $themes[$ThemeName]
    if ($null -eq $c) { $c = $themes["Default"] }

    $xaml = @'
        <!-- TabControl -->
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="{{Base}}"/>
            <Setter Property="BorderBrush" Value="{{Surface1}}"/>
        </Style>

        <!-- ScrollViewer -->
        <Style TargetType="ScrollViewer">
            <Setter Property="Background" Value="{{Base}}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollViewer">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <ScrollContentPresenter Grid.Column="0" Grid.Row="0"
                                CanContentScroll="{TemplateBinding CanContentScroll}"/>
                            <ScrollBar x:Name="PART_VerticalScrollBar" Grid.Column="1" Grid.Row="0"
                                Value="{TemplateBinding VerticalOffset}"
                                Maximum="{TemplateBinding ScrollableHeight}"
                                ViewportSize="{TemplateBinding ViewportHeight}"
                                Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}"/>
                            <ScrollBar x:Name="PART_HorizontalScrollBar" Grid.Column="0" Grid.Row="1"
                                Orientation="Horizontal"
                                Value="{TemplateBinding HorizontalOffset}"
                                Maximum="{TemplateBinding ScrollableWidth}"
                                ViewportSize="{TemplateBinding ViewportWidth}"
                                Visibility="{TemplateBinding ComputedHorizontalScrollBarVisibility}"/>
                            <Rectangle Grid.Column="1" Grid.Row="1" Fill="{{Base}}"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- TabItem -->
        <Style TargetType="TabItem">
            <Setter Property="Foreground" Value="{{Subtext1}}"/>
            <Setter Property="Background" Value="{{Surface0}}"/>
            <Setter Property="BorderBrush" Value="{{Surface1}}"/>
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
                                <Setter TargetName="tabBorder" Property="Background" Value="{{Surface1}}"/>
                                <Setter Property="Foreground" Value="{{Mauve}}"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                    <Condition Property="IsSelected" Value="False"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="tabBorder" Property="Background" Value="{{Surface2}}"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Label -->
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,6,0,2"/>
        </Style>

        <!-- TextBox -->
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="{{Surface0}}"/>
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="BorderBrush" Value="{{Surface2}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="{{Text}}"/>
        </Style>

        <!-- ComboBox -->
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="{{Surface0}}"/>
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="BorderBrush" Value="{{Surface2}}"/>
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
                                                <Path Grid.Column="1" Data="M0,0 L4,4 8,0" Stroke="{{Text}}"
                                                      StrokeThickness="1.5" HorizontalAlignment="Center"
                                                      VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                                <ToggleButton.Background>
                                    <SolidColorBrush Color="{{Surface0}}"/>
                                </ToggleButton.Background>
                                <ToggleButton.BorderBrush>
                                    <SolidColorBrush Color="{{Surface2}}"/>
                                </ToggleButton.BorderBrush>
                            </ToggleButton>
                            <ContentPresenter x:Name="contentPresenter"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="10,6,28,6" VerticalAlignment="Center"
                                              HorizontalAlignment="Left" IsHitTestVisible="False"/>
                            <TextBox x:Name="PART_EditableTextBox" Visibility="Collapsed"
                                     Background="Transparent" Foreground="{{Text}}"
                                     CaretBrush="{{Text}}" FontSize="13"
                                     Margin="8,4,28,4" VerticalAlignment="Center"
                                     HorizontalAlignment="Stretch" Focusable="True"
                                     IsReadOnly="{TemplateBinding IsReadOnly}"/>
                            <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   Placement="Bottom" AllowsTransparency="True" Focusable="False"
                                   PopupAnimation="Slide">
                                <Border Background="{{Surface0}}" BorderBrush="{{Surface2}}" BorderThickness="1"
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

        <!-- ComboBoxItem -->
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{Surface0}}"/>
            <Setter Property="Foreground" Value="{{Text}}"/>
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
                                <Setter TargetName="itemBorder" Property="Background" Value="{{Surface2}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- CheckBox -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,6,0,2"/>
        </Style>

        <!-- TreeView -->
        <Style TargetType="TreeView">
            <Setter Property="Background" Value="{{Mantle}}"/>
            <Setter Property="BorderBrush" Value="{{Surface0}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="4"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        </Style>

        <!-- TreeViewItem -->
        <Style TargetType="TreeViewItem">
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="2,2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TreeViewItem">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition/>
                            </Grid.RowDefinitions>
                            <Border x:Name="Bd" Grid.Row="0"
                                    Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    Padding="{TemplateBinding Padding}">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto" MinWidth="16"/>
                                        <ColumnDefinition/>
                                    </Grid.ColumnDefinitions>
                                    <ToggleButton x:Name="Expander" Grid.Column="0"
                                                  IsChecked="{Binding IsExpanded, RelativeSource={RelativeSource TemplatedParent}}"
                                                  ClickMode="Press" Focusable="False"
                                                  Width="16" Height="16">
                                        <ToggleButton.Template>
                                            <ControlTemplate TargetType="ToggleButton">
                                                <Border Background="Transparent" Width="16" Height="16">
                                                    <Path x:Name="arrow" Data="M0,0 L4,4 8,0"
                                                          Stroke="{{Subtext0}}" StrokeThickness="1.5"
                                                          HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                </Border>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsChecked" Value="False">
                                                        <Setter TargetName="arrow" Property="Data" Value="M0,4 L4,0 8,4"/>
                                                    </Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </ToggleButton.Template>
                                    </ToggleButton>
                                    <ContentPresenter x:Name="PART_Header" Grid.Column="1"
                                                      ContentSource="Header"
                                                      HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                                      VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                            <ItemsPresenter x:Name="ItemsHost" Grid.Row="1" Margin="16,0,0,0"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsExpanded" Value="False">
                                <Setter TargetName="ItemsHost" Property="Visibility" Value="Collapsed"/>
                            </Trigger>
                            <Trigger Property="HasItems" Value="False">
                                <Setter TargetName="Expander" Property="Visibility" Value="Hidden"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{Surface1}}"/>
                                <Setter Property="Foreground" Value="{{Mauve}}"/>
                            </Trigger>
                            <Trigger SourceName="Bd" Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{Surface0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- RunButton -->
        <Style x:Key="RunButton" TargetType="Button">
            <Setter Property="Background" Value="{{Mauve}}"/>
            <Setter Property="Foreground" Value="{{Base}}"/>
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
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Lavender}}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Surface2}}"/>
                                <Setter Property="Foreground" Value="{{Overlay0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- DangerButton -->
        <Style x:Key="DangerButton" TargetType="Button">
            <Setter Property="Background" Value="{{Red}}"/>
            <Setter Property="Foreground" Value="{{Base}}"/>
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
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Maroon}}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Surface2}}"/>
                                <Setter Property="Foreground" Value="{{Overlay0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- SmallButton -->
        <Style x:Key="SmallButton" TargetType="Button">
            <Setter Property="Background" Value="{{Surface1}}"/>
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="10,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="btnBorder" Background="{TemplateBinding Background}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Surface2}}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Surface0}}"/>
                                <Setter Property="Foreground" Value="{{Overlay0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- CardButton -->
        <Style x:Key="CardButton" TargetType="Button">
            <Setter Property="Background" Value="{{Surface1}}"/>
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Margin" Value="0,0,6,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="btnBorder" Background="{TemplateBinding Background}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="btnBorder" Property="Background" Value="{{Surface2}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- TitleBarButton -->
        <Style x:Key="TitleBarButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{{Subtext0}}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="46"/>
            <Setter Property="Height" Value="36"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bg" Background="{TemplateBinding Background}"
                                Width="46" Height="36">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="{{Surface0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- TitleBarCloseButton -->
        <Style x:Key="TitleBarCloseButton" TargetType="Button" BasedOn="{StaticResource TitleBarButton}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bg" Background="{TemplateBinding Background}"
                                Width="46" Height="36">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="{{Red}}"/>
                                <Setter Property="Foreground" Value="{{Base}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ContextMenu -->
        <Style TargetType="ContextMenu">
            <Setter Property="Background" Value="{{Surface0}}"/>
            <Setter Property="Foreground" Value="{{Text}}"/>
            <Setter Property="BorderBrush" Value="{{Surface1}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="2"/>
        </Style>

        <!-- ScrollBar Thumb -->
        <Style x:Key="ScrollBarThumb" TargetType="Thumb">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="IsTabStop" Value="False"/>
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border x:Name="thumbBorder" Background="{{Surface1}}" CornerRadius="4"/>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="thumbBorder" Property="Background" Value="{{Surface2}}"/>
                            </Trigger>
                            <Trigger Property="IsDragging" Value="True">
                                <Setter TargetName="thumbBorder" Property="Background" Value="{{Overlay0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ScrollBar track area -->
        <Style x:Key="ScrollBarPageButton" TargetType="RepeatButton">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="IsTabStop" Value="False"/>
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RepeatButton">
                        <Border Background="Transparent"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ScrollBar arrow buttons -->
        <Style x:Key="ScrollBarLineButton" TargetType="RepeatButton">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RepeatButton">
                        <Border x:Name="arrowBorder" Background="{{Base}}" BorderThickness="0">
                            <Path x:Name="arrowPath" HorizontalAlignment="Center"
                                  VerticalAlignment="Center" Fill="{{Surface2}}"
                                  Data="{Binding Content, RelativeSource={RelativeSource TemplatedParent}}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="arrowPath" Property="Fill" Value="{{Subtext0}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Vertical ScrollBar template -->
        <ControlTemplate x:Key="VerticalScrollBar" TargetType="ScrollBar">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition MaxHeight="14"/>
                    <RowDefinition Height="0.00001*"/>
                    <RowDefinition MaxHeight="14"/>
                </Grid.RowDefinitions>
                <Border Grid.RowSpan="3" Background="{{Base}}"/>
                <RepeatButton Grid.Row="0" Style="{StaticResource ScrollBarLineButton}"
                              Height="14" Command="ScrollBar.LineUpCommand"
                              Content="M 0 4 L 4 0 L 8 4 Z"/>
                <Track x:Name="PART_Track" Grid.Row="1" IsDirectionReversed="True">
                    <Track.DecreaseRepeatButton>
                        <RepeatButton Style="{StaticResource ScrollBarPageButton}"
                                      Command="ScrollBar.PageUpCommand"/>
                    </Track.DecreaseRepeatButton>
                    <Track.Thumb>
                        <Thumb Style="{StaticResource ScrollBarThumb}" MinHeight="20" Margin="2,0"/>
                    </Track.Thumb>
                    <Track.IncreaseRepeatButton>
                        <RepeatButton Style="{StaticResource ScrollBarPageButton}"
                                      Command="ScrollBar.PageDownCommand"/>
                    </Track.IncreaseRepeatButton>
                </Track>
                <RepeatButton Grid.Row="2" Style="{StaticResource ScrollBarLineButton}"
                              Height="14" Command="ScrollBar.LineDownCommand"
                              Content="M 0 0 L 4 4 L 8 0 Z"/>
            </Grid>
        </ControlTemplate>

        <!-- Horizontal ScrollBar template -->
        <ControlTemplate x:Key="HorizontalScrollBar" TargetType="ScrollBar">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition MaxWidth="14"/>
                    <ColumnDefinition Width="0.00001*"/>
                    <ColumnDefinition MaxWidth="14"/>
                </Grid.ColumnDefinitions>
                <Border Grid.ColumnSpan="3" Background="{{Base}}"/>
                <RepeatButton Grid.Column="0" Style="{StaticResource ScrollBarLineButton}"
                              Width="14" Command="ScrollBar.LineLeftCommand"
                              Content="M 4 0 L 0 4 L 4 8 Z"/>
                <Track x:Name="PART_Track" Grid.Column="1" IsDirectionReversed="False">
                    <Track.DecreaseRepeatButton>
                        <RepeatButton Style="{StaticResource ScrollBarPageButton}"
                                      Command="ScrollBar.PageLeftCommand"/>
                    </Track.DecreaseRepeatButton>
                    <Track.Thumb>
                        <Thumb Style="{StaticResource ScrollBarThumb}" MinWidth="20" Margin="0,2"/>
                    </Track.Thumb>
                    <Track.IncreaseRepeatButton>
                        <RepeatButton Style="{StaticResource ScrollBarPageButton}"
                                      Command="ScrollBar.PageRightCommand"/>
                    </Track.IncreaseRepeatButton>
                </Track>
                <RepeatButton Grid.Column="2" Style="{StaticResource ScrollBarLineButton}"
                              Width="14" Command="ScrollBar.LineRightCommand"
                              Content="M 0 0 L 4 4 L 0 8 Z"/>
            </Grid>
        </ControlTemplate>

        <!-- ScrollBar style -->
        <Style TargetType="ScrollBar">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Vertical">
                    <Setter Property="Width" Value="14"/>
                    <Setter Property="Height" Value="Auto"/>
                    <Setter Property="Template" Value="{StaticResource VerticalScrollBar}"/>
                </Trigger>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Width" Value="Auto"/>
                    <Setter Property="Height" Value="14"/>
                    <Setter Property="Template" Value="{StaticResource HorizontalScrollBar}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
'@

    # Replacement
    foreach ($key in $c.Keys) {
        $xaml = $xaml.Replace("{{$key}}", $c[$key])
    }

    return $xaml
}

function Get-ThemeColors {
    param([string]$ThemeName = "Default")
    
    $themes = @{
        "Default" = @{
            Base      = "#1e1e2e"; Mantle = "#181825"; Crust = "#11111b"
            Text      = "#cdd6f4"; Subtext0 = "#a6adc8"; Subtext1 = "#bac2de"
            Surface0  = "#313244"; Surface1 = "#45475a"; Surface2 = "#585b70"
            Overlay0  = "#6c7086"; Overlay1 = "#7f849c"; Overlay2 = "#9399b2"
            Blue      = "#89b4fa"; Lavender = "#b4befe"; Sapphire = "#74c7ec"; Sky = "#89dceb"
            Mauve     = "#cba6f7"; Pink = "#f5c2e7"; Flamingo = "#f2cdcd"; Rosewater = "#f5e0dc"
            Red       = "#f38ba8"; Peach = "#fab387"; Yellow = "#f9e2af"; Green = "#a6e3a1"
            Teal      = "#94e2d5"; Maroon = "#eba0ac"
        }
        "GitHub" = @{
            Base      = "#0d1117"; Mantle = "#010409"; Crust = "#010409"
            Text      = "#c9d1d9"; Subtext0 = "#8b949e"; Subtext1 = "#b1bac4"
            Surface0  = "#161b22"; Surface1 = "#30363d"; Surface2 = "#484f58"
            Overlay0  = "#6e7681"; Overlay1 = "#8b949e"; Overlay2 = "#b1bac4"
            Blue      = "#58a6ff"; Lavender = "#a5d6ff"; Sapphire = "#388bfd"; Sky = "#79c0ff"
            Mauve     = "#58a6ff"; Pink = "#ff7b72"; Flamingo = "#ffa198"; Rosewater = "#ff7b72"
            Red       = "#f85149"; Peach = "#ffa657"; Yellow = "#e3b341"; Green = "#7ee787"
            Teal      = "#7ee787"; Maroon = "#f85149"
        }
    }
    
    $c = $themes[$ThemeName]
    if ($null -eq $c) { $c = $themes["Default"] }
    return $c
}
