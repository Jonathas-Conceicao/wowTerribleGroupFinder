@echo off
rem Thin wrapper: builds a local test zip in dist\ (see package.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package.ps1" %*
exit /b %errorlevel%
