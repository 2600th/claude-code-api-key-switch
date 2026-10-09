@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-api-check.ps1" %*
exit /b %ERRORLEVEL%
