# Shared helpers for the claude-api scripts. Dot-source only; never prints the key.

$script:DefaultEnvFile = Join-Path $PSScriptRoot '.env.claude'   # private; git-ignored

function Get-ClaudeApiKey {
    <#
      Reads the Anthropic API key from $env:CLAUDE_API_ENV_FILE, or from .env.claude next to
      these scripts by default (copy .env.claude.example to create it).
      Accepts either a bare "sk-ant-..." line or ANTHROPIC_API_KEY=... (quotes and "export" allowed).
      Throws with a message that never contains the key.
    #>
    $file = if ($env:CLAUDE_API_ENV_FILE) { $env:CLAUDE_API_ENV_FILE } else { $script:DefaultEnvFile }
    if (-not (Test-Path -LiteralPath $file)) { throw "claude-api: key file not found: $file (copy .env.claude.example to .env.claude and add your key)" }
    foreach ($raw in [IO.File]::ReadAllLines($file)) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -match '^(export\s+)?ANTHROPIC_API_KEY\s*[=:]\s*(.+)$') { $line = $Matches[2].Trim() }
        $line = $line.Trim('"', "'")
        if ($line.StartsWith('sk-ant-')) { return $line }
    }
    throw "claude-api: no key found in $file (expected a 'sk-ant-...' line or ANTHROPIC_API_KEY=...)"
}

function Get-ClaudeWorkspaceId {
    # Needed only for user-scoped keys (sk-ant-usr...): ANTHROPIC_WORKSPACE_ID=wrkspc_... in the key file or the environment.
    if ($env:ANTHROPIC_WORKSPACE_ID) { return $env:ANTHROPIC_WORKSPACE_ID }
    $file = if ($env:CLAUDE_API_ENV_FILE) { $env:CLAUDE_API_ENV_FILE } else { $script:DefaultEnvFile }
    foreach ($raw in [IO.File]::ReadAllLines($file)) {
        if ($raw.Trim() -match '^(export\s+)?ANTHROPIC_WORKSPACE_ID\s*[=:]\s*(.+)$') { return $Matches[2].Trim().Trim('"', "'") }
    }
    return $null
}

function Set-ClaudeApiEnv {
    # Puts the key (and workspace header, if any) into THIS process environment only.
    $env:ANTHROPIC_API_KEY = Get-ClaudeApiKey
    Remove-Item Env:CLAUDE_CODE_OAUTH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    $ws = Get-ClaudeWorkspaceId
    if ($ws) {
        $env:ANTHROPIC_WORKSPACE_ID = $ws
        $hdr = "anthropic-workspace-id: $ws"
        $headers = @($env:ANTHROPIC_CUSTOM_HEADERS -split '\r?\n' | Where-Object { $_ -and $_ -notmatch '^\s*anthropic-workspace-id:' })
        $env:ANTHROPIC_CUSTOM_HEADERS = ($headers + $hdr) -join "`n"
    } elseif ($env:ANTHROPIC_API_KEY.StartsWith('sk-ant-usr')) {
        Write-Warning 'claude-api: this is a user-scoped key; add ANTHROPIC_WORKSPACE_ID=wrkspc_... to the key file (see README).'
    }
}

function Get-ClaudeExe {
    $cmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { throw "claude-api: 'claude' CLI not found on PATH" }
    return $cmd.Source
}
