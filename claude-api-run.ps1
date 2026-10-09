<#
.SYNOPSIS
  Headless Claude "subagent" billed to the API key: claude -p with a prompt file, a budget cap and an output file.
.EXAMPLE
  claude-api-run -PromptFile task.md -OutFile out.md -Model claude-sonnet-5-5 -MaxBudgetUsd 3
.EXAMPLE
  Get-Content task.md | claude-api-run -Model claude-haiku-4-5-20251001 -Cwd C:\path\to\repo
.NOTES
  -Effort low|medium|high|xhigh|max sets the reasoning effort (claude --effort); omitted = the CLI default.
  Defaults: model claude-sonnet-5-5, budget $5, 40 turns, permission mode acceptEdits (edits allowed, other tools
  follow your normal allow-lists). Use -PermissionMode bypassPermissions only for trusted, sandboxed work.
  The exit code is claude's. With -Json the output is the JSON result (it includes cost and session id).
  Cost floor: each fresh run first writes Claude Code's system prompt and tools into the prompt cache, which is
  about $0.08 on Haiku and more on bigger models, even for a one-word answer. -Bare skips CLAUDE.md
  discovery, hooks and plugins to cut it; give the full context in the prompt instead. Use full model ids:
  the CLI's 'haiku'/'sonnet' aliases may resolve to older models.
#>
[CmdletBinding()]
param(
    [string]$Prompt,
    [string]$PromptFile,
    [string]$OutFile,
    [string]$Model = 'claude-sonnet-5-5',
    [double]$MaxBudgetUsd = 5,
    [int]$MaxTurns = 40,
    [ValidateSet('acceptEdits', 'auto', 'bypassPermissions', 'manual', 'dontAsk', 'plan')]
    [string]$PermissionMode = 'acceptEdits',
    [ValidateSet('low', 'medium', 'high', 'xhigh', 'max')]
    [string]$Effort,
    [string]$Cwd = (Get-Location).Path,
    [string[]]$AddDir = @(),
    [string]$AllowedTools,
    [string]$AppendSystemPrompt,
    [switch]$Json,
    [switch]$Bare,
    [switch]$DryRun,
    [Parameter(ValueFromPipeline = $true)] [string]$InputLine
)
begin { $piped = [System.Collections.Generic.List[string]]::new() }
process { if ($PSBoundParameters.ContainsKey('InputLine')) { $piped.Add($InputLine) } }
end {
    $ErrorActionPreference = 'Stop'
    . (Join-Path $PSScriptRoot 'lib.ps1')

    if ($PromptFile) { $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PromptFile)) }
    elseif ($Prompt) { $text = $Prompt }
    elseif ($piped.Count) { $text = $piped -join "`n" }
    elseif ([Console]::IsInputRedirected) { $text = [Console]::In.ReadToEnd() }
    else { throw 'claude-api-run: give -Prompt, -PromptFile or pipe the prompt on stdin' }
    if (-not $text) { throw 'claude-api-run: the prompt is empty' }
    if ($OutFile) { $OutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile) }

    Set-ClaudeApiEnv
    $exe = Get-ClaudeExe

    $argv = @('-p', '--model', $Model, '--max-budget-usd', $MaxBudgetUsd.ToString([Globalization.CultureInfo]::InvariantCulture), '--max-turns', "$MaxTurns",
              '--permission-mode', $PermissionMode, '--output-format', ($(if ($Json) { 'json' } else { 'text' })))
    foreach ($d in $AddDir) { $argv += @('--add-dir', $d) }
    if ($Effort) { $argv += @('--effort', $Effort) }
    if ($Bare) { $argv += '--bare' }
    if ($AllowedTools) { $argv += @('--allowedTools', $AllowedTools) }
    if ($AppendSystemPrompt) { $argv += @('--append-system-prompt', $AppendSystemPrompt) }

    if ($DryRun) {
        Write-Output ("would run in {0}: claude {1}" -f $Cwd, ($argv -join ' '))
        Write-Output ("prompt: {0} chars; key set: {1}; workspace header: {2}" -f $text.Length, [bool]$env:ANTHROPIC_API_KEY, [bool]$env:ANTHROPIC_CUSTOM_HEADERS)
        exit 0
    }

    Push-Location -LiteralPath $Cwd
    $oldOutputEncoding = $OutputEncoding
    $oldConsoleEncoding = $null
    $oldInputEncoding = $null
    $writer = $null
    try {
        $OutputEncoding = [Text.UTF8Encoding]::new($false)
        try {
            $oldConsoleEncoding = [Console]::OutputEncoding
            [Console]::OutputEncoding = $OutputEncoding
        } catch {}
        # With a console attached, 5.1 prepends a BOM to the native stdin unless InputEncoding is BOM-less UTF-8 too.
        try {
            $oldInputEncoding = [Console]::InputEncoding
            [Console]::InputEncoding = $OutputEncoding
        } catch {}
        # The prompt goes in on stdin: no command-line length limit, and it never shows in process lists.
        if ($OutFile) {
            $writer = [IO.StreamWriter]::new($OutFile, $false, $OutputEncoding)
            $text | & $exe @argv | ForEach-Object { $writer.WriteLine($_) }
        } else {
            $text | & $exe @argv
        }
        $code = $LASTEXITCODE
    } finally {
        try { if ($writer) { $writer.Dispose() } } finally {
            $OutputEncoding = $oldOutputEncoding
            if ($oldConsoleEncoding) { try { [Console]::OutputEncoding = $oldConsoleEncoding } catch {} }
            if ($oldInputEncoding) { try { [Console]::InputEncoding = $oldInputEncoding } catch {} }
            Pop-Location
        }
    }
    exit $code
}
