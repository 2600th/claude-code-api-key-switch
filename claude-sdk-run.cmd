@echo off
if not exist "%~dp0.venv\Scripts\python.exe" (echo claude-sdk-run: run setup first ^(creates .venv with the Agent SDK^) 1>&2 & exit /b 1)
"%~dp0.venv\Scripts\python.exe" "%~dp0claude_sdk_run.py" %*
exit /b %ERRORLEVEL%
