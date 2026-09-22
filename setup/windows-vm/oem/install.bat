@echo off
rem Runs once at the end of Windows setup (dockur/windows copies /oem to C:\OEM).
rem Installs the provisioning toolchain; log in C:\OEM\bootstrap.log.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1"
