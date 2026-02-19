@echo off
:: exec_project_manager.cmd - Launch the Project Manager GUI
:: Double-click this file to start the application

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_projectTemplate\scripts\project_manager.ps1"
