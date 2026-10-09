@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-api.ps1" %*
exit /b %ERRORLEVEL%
