<#
.SYNOPSIS
  Run Claude Code billed to your Anthropic API key instead of the subscription.
.DESCRIPTION
  The key is set only in this process and its children. All arguments pass through to `claude`.
  Examples:
    claude-api                    # new interactive session on the API key
    claude-api --continue         # continue the most recent conversation here (e.g. after a usage limit)
    claude-api --resume <id>      # resume a specific session
    claude-api --model opus       # any normal claude flag works
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Set-ClaudeApiEnv

$exe = Get-ClaudeExe
& $exe @args
exit $LASTEXITCODE
