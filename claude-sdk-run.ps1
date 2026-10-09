# Headless Claude subagent via the Agent SDK (bills as Agent SDK; see claude_sdk_run.py --help).
$py = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $py)) { Write-Error 'claude-sdk-run: run setup first (creates .venv with the Agent SDK)'; exit 1 }
if ($MyInvocation.ExpectingInput) {
    $OutputEncoding = [Text.UTF8Encoding]::new($false)   # Windows PowerShell 5.1 pipes ASCII by default
    $input | & $py (Join-Path $PSScriptRoot 'claude_sdk_run.py') @args
}
else { & $py (Join-Path $PSScriptRoot 'claude_sdk_run.py') @args }
exit $LASTEXITCODE
