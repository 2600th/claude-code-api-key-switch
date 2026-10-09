@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set "code=%ERRORLEVEL%"
pause
exit /b %code%
