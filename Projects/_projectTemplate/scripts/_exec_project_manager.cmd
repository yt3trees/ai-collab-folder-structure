@echo off
:: _exec_project_manager.cmd - Launch the Project Manager GUI
:: Double-click this file to start the application

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0project_manager.ps1"
