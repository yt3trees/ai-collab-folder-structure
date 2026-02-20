$script:currentPopup = $null

function Add-ContextMenuToTreeItem {
    param([System.Windows.Controls.TreeViewItem]$Item, [System.Windows.Window]$Window)

    # Only add context menu to files (items with FilePath)
    if ($null -eq $Item.Tag) { return }

    $filePath = $Item.Tag
    $fileName = [System.IO.Path]::GetFileName($filePath)

    # DO NOT overwrite Item.Tag - it contains the file path needed by SelectedItemChanged
    # Store context menu data locally in the closure

    # Attach right-click handler to TreeViewItem
    $Item.Add_MouseRightButtonUp({
            param($sender, $e)
            $e.Handled = $true

            # Get file path from sender's Tag (preserves string format for SelectedItemChanged compatibility)
            $localFilePath = $sender.Tag
            $localFileName = [System.IO.Path]::GetFileName($localFilePath)
        
            # Close existing popup if any
            if ($null -ne $script:currentPopup) {
                $script:currentPopup.IsOpen = $false
                $script:currentPopup = $null
            }
        
            # Create a Popup-based custom context menu
            $popup = New-Object System.Windows.Controls.Primitives.Popup
            $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Mouse
            $popup.PlacementTarget = $sender
            $popup.StaysOpen = $false
            $popup.AllowsTransparency = $true
        
            # Border container
            $border = New-Object System.Windows.Controls.Border
            $border.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#313244"))
            $border.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#45475a"))
            $border.BorderThickness = New-Object System.Windows.Thickness(1)
            $border.Padding = New-Object System.Windows.Thickness(2)
        
            # Menu item as TextBlock
            $menuText = New-Object System.Windows.Controls.TextBlock
            $menuText.Text = "Delete"
            $menuText.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#f38ba8"))
            $menuText.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#313244"))
            $menuText.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)
            $menuText.Cursor = [System.Windows.Input.Cursors]::Hand
        
            # Store data in the TextBlock's Tag
            $menuText.Tag = @{ 
                FilePath = $localFilePath 
                FileName = $localFileName 
                Popup    = $popup
                Window   = $Window
            }
        
            # Mouse enter/leave for hover effect
            $menuText.Add_MouseEnter({
                    $this.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#45475a"))
                })
        
            $menuText.Add_MouseLeave({
                    $this.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#313244"))
                })
        
            # Click handler
            $menuText.Add_MouseLeftButtonDown({
                    param($sender, $e)
                    $e.Handled = $true
                    $data = $sender.Tag
                    $filePath = $data.FilePath
                    $fileName = $data.FileName
                    $popup = $data.Popup
                    $Window = $data.Window
            
                    # Close popup
                    $popup.IsOpen = $false
                    $script:currentPopup = $null
            
                    # Validate path
                    if ([string]::IsNullOrEmpty($filePath) -or -not (Test-Path $filePath)) {
                        [System.Windows.MessageBox]::Show(
                            "File not found or invalid path.",
                            "Cannot Delete",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning
                        ) | Out-Null
                        return
                    }
            
                    # Get parent directory name
                    $parentDir = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($filePath))
            
                    # Only allow deletion of files in decision_log folder
                    if ($parentDir -ne 'decision_log') {
                        [System.Windows.MessageBox]::Show(
                            "Only decision_log files can be deleted.",
                            "Cannot Delete",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning
                        ) | Out-Null
                        return
                    }
            
                    # Prevent deletion of TEMPLATE.md
                    if ($fileName -eq "TEMPLATE.md") {
                        [System.Windows.MessageBox]::Show(
                            "TEMPLATE.md cannot be deleted.",
                            "Cannot Delete",
                            [System.Windows.MessageBoxButton]::OK,
                            [System.Windows.MessageBoxImage]::Warning
                        ) | Out-Null
                        return
                    }
            
                    # Confirm deletion
                    $result = [System.Windows.MessageBox]::Show(
                        "Are you sure you want to delete '$fileName'?`n`nThis action cannot be undone.",
                        "Confirm Delete",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Warning
                    )
            
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        if ($script:AppState.EditorState.CurrentFile -eq $filePath -and $script:AppState.EditorState.IsDirty) {
                            $discardRes = [System.Windows.MessageBox]::Show(
                                "This file has unsaved changes. Deleting will discard your changes.`nContinue?",
                                "Unsaved Changes",
                                [System.Windows.MessageBoxButton]::YesNo,
                                [System.Windows.MessageBoxImage]::Warning
                            )
                            if ($discardRes -ne [System.Windows.MessageBoxResult]::Yes) { return }
                        }
                        try {
                            Remove-Item -Path $filePath -Force
                    
                            # Clear editor if the deleted file was open
                            $currentFile = $script:AppState.EditorState.CurrentFile
                            if ($currentFile -eq $filePath) {
                                $ed = $script:AppState.EditorControl
                                $script:AppState.EditorState.SuppressChangeEvent = $true
                                $ed.Text = ""
                                $ed.IsReadOnly = $true
                                $script:AppState.EditorState.SuppressChangeEvent = $false
                                $Window.FindName("editorStatusText").Text = "No file open"
                        
                                $script:AppState.EditorState.CurrentFile = ""
                                $script:AppState.EditorState.OriginalContent = ""
                                $script:AppState.EditorState.IsDirty = $false
                        
                                Update-StatusBar -Window $Window -File "" -Encoding "" -Dirty $false
                            }
                    
                            # Refresh tree
                            $combo = $Window.FindName("editorProjectCombo")
                            $selText = if ($null -ne $combo.SelectedItem) { $combo.SelectedItem.ToString() } else { "" }
                            $proj = Get-SelectedEditorProject -ComboText $selText
                            if ($null -ne $proj) {
                                Populate-FileTree `
                                    -Tree            $Window.FindName("editorFileTree") `
                                    -WorkspaceTree   $Window.FindName("editorWorkspaceTree") `
                                    -ProjectInfo     $proj `
                                    -WorkspaceRoot   $script:AppState.WorkspaceRoot `
                                    -Window          $Window
                            }
                        }
                        catch {
                            [System.Windows.MessageBox]::Show(
                                "Failed to delete file:`n$($_.Exception.Message)",
                                "Delete Error",
                                [System.Windows.MessageBoxButton]::OK,
                                [System.Windows.MessageBoxImage]::Error
                            ) | Out-Null
                        }
                    }
                })
        
            $border.Child = $menuText
            $popup.Child = $border
        
            # Store reference and open
            $script:currentPopup = $popup
            $popup.IsOpen = $true
        })
}
