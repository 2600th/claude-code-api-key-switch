<#
.SYNOPSIS
  Check the API key without printing it. With -Online it also calls GET /v1/models (free, no tokens used).
#>
param([switch]$Online)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$ready = $true
$key = $null
$wsId = $null
try {
    $key = Get-ClaudeApiKey
    Write-Output ("key: found ({0} chars, prefix ok)" -f $key.Length)
    $wsId = Get-ClaudeWorkspaceId
} catch {
    Write-Output $_.Exception.Message
    $ready = $false
}
try { Write-Output ("claude CLI: {0}" -f (Get-ClaudeExe)) } catch {
    Write-Output 'claude CLI: NOT FOUND - install Claude Code first: https://code.claude.com/docs'
    $ready = $false
}
if ($wsId) { Write-Output "workspace: $wsId" }
elseif ($key -and $key.StartsWith('sk-ant-usr')) {
    Write-Output 'workspace: MISSING (user-scoped key needs ANTHROPIC_WORKSPACE_ID)'
    $ready = $false
} elseif ($key) { Write-Output 'workspace: not needed (workspace-scoped key)' }
else { Write-Output 'workspace: not checked (key unavailable)' }
if ($Online -and $key) {
    $headers = @{ 'x-api-key' = $key; 'anthropic-version' = '2023-06-01' }
    if ($wsId) { $headers['anthropic-workspace-id'] = $wsId }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod -Uri 'https://api.anthropic.com/v1/models?limit=5' -Headers $headers -Method Get
        Write-Output ("api: OK - models visible: {0}" -f (($r.data | ForEach-Object id) -join ', '))
    } catch {
        if ($_.Exception.Response) {
            $status = $_.Exception.Response.StatusCode.value__
            $detail = $_.ErrorDetails.Message
            if (-not $detail) { $detail = $_.Exception.Message }
            try { $detail = ($detail | ConvertFrom-Json).error.message } catch {}
            Write-Output ("api: FAILED (HTTP {0}) - {1}" -f $status, $detail)
        } else { Write-Output ("api: FAILED - {0}" -f $_.Exception.Message) }
        $ready = $false
    }
}
if ($ready) { Write-Output "READY: use claude-api or claude-api-run in any project folder."; exit 0 }
Write-Output 'NOT READY: fix the lines above.'
exit 1
