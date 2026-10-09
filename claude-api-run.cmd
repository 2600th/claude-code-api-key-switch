@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-api-run.ps1" %*
exit /b %ERRORLEVEL%
