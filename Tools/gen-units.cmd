@echo off
rem ---------------------------------------------------------------------
rem Regenerates the per-framework unit copies under Generated\.
rem
rem   gen-units.cmd [-Check]
rem
rem PowerShell rather than Python because it is on every Windows machine
rem this has to run on, and this script is called from the build scripts
rem where a missing interpreter would read as a compiler failure.
rem
rem The build scripts call this first. Running it by hand is only needed
rem when something has to be inspected between generating and compiling.
rem ---------------------------------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gen-units.ps1" %*
exit /b %ERRORLEVEL%
