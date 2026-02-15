@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "project_launcher.ps1"
