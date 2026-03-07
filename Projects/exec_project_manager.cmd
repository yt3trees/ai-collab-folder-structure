@echo off
:: exec_project_manager.cmd - Launch the Project Manager GUI
:: Double-click this file to start the application

:: Stop any existing instance of project_manager.ps1
wmic process where "Name='powershell.exe' AND CommandLine LIKE '%%project_manager.ps1%%'" call terminate >nul 2>&1

start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0_projectTemplate\scripts\project_manager.ps1"
