<#
.SYNOPSIS
  Set up claude-api for this Windows user.
.PARAMETER NoPath
  Skip adding this folder to the user Path.
.PARAMETER NoCheck
  Skip the online checks.
.PARAMETER ApiKey
  For automation in isolated test folders; normally the key is requested securely.
.PARAMETER WorkspaceId
  Workspace id for automation with a user-scoped key.
#>
[CmdletBinding()]
param(
    [switch]$NoPath,
    [switch]$NoCheck,
    [Parameter(DontShow = $true)] [string]$ApiKey,
    [Parameter(DontShow = $true)] [string]$WorkspaceId
)
$ErrorActionPreference = 'Stop'
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File | Unblock-File
Write-Output 'Scripts unblocked.'

# Windows blocks .ps1 files by default, and PowerShell runs claude-api.ps1 before claude-api.cmd.
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Undefined') { $policy = Get-ExecutionPolicy -Scope LocalMachine }
if ($policy -in 'Restricted', 'Undefined') {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Output 'PowerShell can now run local scripts (RemoteSigned, your user only).'
    } catch {
        Write-Output "Could not allow scripts: $($_.Exception.Message) In PowerShell, use claude-api.cmd instead of claude-api."
    }
}

$file = Join-Path $PSScriptRoot '.env.claude'
if (Test-Path -LiteralPath $file) {
    Write-Output 'Key file .env.claude already exists. Leaving it as is.'
} else {
    if (-not $PSBoundParameters.ContainsKey('ApiKey')) {
        Write-Output 'Get a key at platform.claude.com > API Keys.'
        Write-Output 'Tip: to use your Max/Team monthly API credits, create it in the Console organization linked to your plan.'
        while ($true) {
            $secureKey = Read-Host 'Paste your Anthropic API key (right-click to paste; it stays hidden)' -AsSecureString
            $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
            try { $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr).Trim() }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); $secureKey.Dispose() }
            if ($ApiKey.StartsWith('sk-ant-')) { break }
            Write-Output 'That does not look like an API key. It should start with sk-ant-. Try again.'
        }
    }
    if (-not $ApiKey -or -not $ApiKey.StartsWith('sk-ant-') -or $ApiKey -match '\s') {
        throw 'The API key must start with sk-ant- and contain no spaces.'
    }
    if ($ApiKey.StartsWith('sk-ant-usr') -and -not $PSBoundParameters.ContainsKey('WorkspaceId')) {
        Write-Output 'This key type needs a workspace ID. Find it at platform.claude.com > Settings > Workspaces.'
        $WorkspaceId = (Read-Host 'Workspace ID (starts with wrkspc_, or press Enter to skip)').Trim()
    }
    if ($WorkspaceId -match '\s') { throw 'The workspace ID must contain no spaces.' }
    $lines = @('# Private. Git ignores this file. Never share or commit it.', "ANTHROPIC_API_KEY=$ApiKey")
    if ($WorkspaceId) { $lines += "ANTHROPIC_WORKSPACE_ID=$WorkspaceId" }
    $body = ($lines -join "`r`n") + "`r`n"
    $stream = [IO.File]::Open($file, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($body)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose(); $ApiKey = $null; $body = $null; $lines = $null; $bytes = $null }
    Write-Output 'Saved your key to .env.claude (private).'
}

if ($NoPath) { Write-Output 'User Path update skipped.' } else {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $folder = $PSScriptRoot.TrimEnd('\')
    $present = @($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $folder }).Count -gt 0
    if ($present) { Write-Output 'This folder is already on your PATH.' } else {
        $newPath = if ($userPath) { $userPath.TrimEnd(';') + ';' + $folder } else { $folder }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Output 'Added this folder to your PATH.'
    }
}
$code = 0
if ($NoCheck) { Write-Output 'Online checks skipped.' } else {
    & (Join-Path $PSScriptRoot 'claude-api-check.ps1') -Online
    $code = $LASTEXITCODE
}
Write-Output ''
Write-Output 'Next: open a NEW terminal, go to your project folder, and type one of:'
Write-Output '  claude-api-run -Prompt "Say hi" -MaxBudgetUsd 1   (headless; Max/Team API credits apply)'
Write-Output '  claude-api --continue                              (continue your chat; uses credit you bought)'
exit $code
