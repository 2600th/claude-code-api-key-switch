#!/usr/bin/env python3
"""Headless Claude subagent through the Claude Agent SDK, billed to the API key in .env.claude.

Why this exists next to claude-api-run: API *promotional* credits often cover "Agent SDK, API, Batch API,
Playground" but not "Claude Code". claude-api-run drives the Claude Code CLI, so it bills as Claude Code;
this runner uses the official Agent SDK (entrypoint sdk-py), so it bills as Agent SDK. Same tools.

Usage (via claude-sdk-run.cmd / claude-sdk-run.ps1 / claude-sdk-run, which use this folder's .venv):
  claude-sdk-run --prompt-file task.md --out result.md --model claude-opus-5-5 --effort high --max-budget-usd 3 --cwd C:/repo
  claude-sdk-run --prompt "..." --json --out result.json          # JSON: result, cost, session id, usage
  claude-sdk-run --prompt "..." --dry-run                          # show the options, spend nothing
  claude-sdk-run --resume <session-id> --prompt "Write the deliverable now." --out result.md   # continue a run
The key never appears in output, logs or arguments.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
KEEP = {"CLAUDE_CONFIG_DIR", "CLAUDE_CODE_GIT_BASH_PATH"}


def read_env_file(path: Path) -> tuple[str, str | None]:
    if not path.is_file():
        sys.exit(f"claude-sdk-run: key file not found: {path} (copy .env.claude.example to .env.claude)")
    key = workspace = None
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        name, sep, value = line.partition("=") if "=" in line else line.partition(":")
        value = value.strip().strip('"').strip("'") if sep else ""
        if sep and name.strip() == "ANTHROPIC_WORKSPACE_ID":
            workspace = value
        elif sep and name.strip() == "ANTHROPIC_API_KEY" and value.startswith("sk-ant-"):
            key = value
        elif not sep and line.strip('"\'').startswith("sk-ant-") and key is None:
            key = line.strip('"\'')
    if not key:
        sys.exit(f"claude-sdk-run: no key found in {path}")
    return key, workspace or os.environ.get("ANTHROPIC_WORKSPACE_ID") or None


def clean_environment(key: str, workspace: str | None) -> None:
    """Start the child from a clean slate: drop inherited Claude/Anthropic session variables
    (desktop-app base URLs, OAuth tokens, host session ids, bare-mode flags), then add ours."""
    for name in list(os.environ):
        upper = name.upper()
        if name not in KEEP and (upper.startswith("CLAUDE") or upper.startswith("ANTHROPIC")):
            del os.environ[name]
    os.environ["ANTHROPIC_API_KEY"] = key
    if workspace:
        os.environ["ANTHROPIC_WORKSPACE_ID"] = workspace
        os.environ["ANTHROPIC_CUSTOM_HEADERS"] = f"anthropic-workspace-id: {workspace}"
    elif key.startswith("sk-ant-usr"):
        print("claude-sdk-run: user-scoped key without ANTHROPIC_WORKSPACE_ID; requests will fail", file=sys.stderr)


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="claude-sdk-run", description=__doc__.split("\n\n")[0])
    p.add_argument("--prompt")
    p.add_argument("--prompt-file")
    p.add_argument("--out", help="write the result (text, or JSON with --json) here")
    p.add_argument("--model", default="claude-sonnet-5-5")
    p.add_argument("--effort", choices=["low", "medium", "high", "xhigh", "max"])
    p.add_argument("--max-budget-usd", type=float, default=5.0)
    p.add_argument("--max-turns", type=int, default=40)
    p.add_argument("--permission-mode", default="acceptEdits",
                   choices=["default", "acceptEdits", "plan", "bypassPermissions", "dontAsk", "auto"])
    p.add_argument("--cwd", default=os.getcwd())
    p.add_argument("--add-dir", action="append", default=[])
    p.add_argument("--allowed-tools", help="comma-separated tool names auto-allowed without prompting")
    p.add_argument("--append-system-prompt")
    p.add_argument("--setting-sources", default="project,local",
                   help="which CLAUDE.md/settings to load: comma list of user,project,local, or 'none'")
    p.add_argument("--json", action="store_true")
    p.add_argument("--verbose", action="store_true", help="stream assistant text to stderr")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--resume", metavar="SESSION_ID",
                   help="continue an earlier session (its id is printed on every exit, including turn/budget caps)")
    a = p.parse_args(argv)
    if a.prompt_file:
        a.text = Path(a.prompt_file).read_text(encoding="utf-8-sig")
    elif a.prompt:
        a.text = a.prompt
    elif not sys.stdin.isatty():
        a.text = sys.stdin.read()
    else:
        p.error("give --prompt, --prompt-file or pipe the prompt on stdin")
    if not a.text.strip():
        p.error("the prompt is empty")
    return a


async def run(a: argparse.Namespace) -> int:
    from claude_agent_sdk import AssistantMessage, ClaudeAgentOptions, ResultMessage, SystemMessage, TextBlock, query

    system_prompt: dict = {"type": "preset", "preset": "claude_code"}
    if a.append_system_prompt:
        system_prompt["append"] = a.append_system_prompt
    sources = [] if a.setting_sources.strip().lower() == "none" else [s.strip() for s in a.setting_sources.split(",") if s.strip()]
    options = ClaudeAgentOptions(
        model=a.model,
        effort=a.effort,
        max_budget_usd=a.max_budget_usd,
        max_turns=a.max_turns,
        permission_mode=a.permission_mode,
        cwd=a.cwd,
        add_dirs=a.add_dir,
        allowed_tools=[t.strip() for t in a.allowed_tools.split(",")] if a.allowed_tools else [],
        system_prompt=system_prompt,
        setting_sources=sources,
        resume=a.resume,
    )
    if a.dry_run:
        print(f"would run in {a.cwd}: model={a.model} effort={a.effort} budget=${a.max_budget_usd} "
              f"turns={a.max_turns} mode={a.permission_mode} settings={sources or 'none'} add_dirs={a.add_dir}")
        print(f"prompt: {len(a.text)} chars; key set: {bool(os.environ.get('ANTHROPIC_API_KEY'))}; "
              f"workspace header: {bool(os.environ.get('ANTHROPIC_CUSTOM_HEADERS'))}")
        return 0

    result: ResultMessage | None = None
    session = a.resume
    try:
        async for message in query(prompt=a.text, options=options):
            if isinstance(message, SystemMessage) and message.subtype == "init":
                session = message.data.get("session_id") or session
            elif isinstance(message, AssistantMessage) and a.verbose:
                for block in message.content:
                    if isinstance(block, TextBlock):
                        print(block.text, file=sys.stderr, flush=True)
            elif isinstance(message, ResultMessage):
                result = message
    except Exception as exc:  # turn/budget caps surface as an exception after (or instead of) the result
        if result is None:
            print(f"claude-sdk-run: {type(exc).__name__}: {exc}", file=sys.stderr)
            print(f"claude-sdk-run: session {session} (continue with --resume {session})", file=sys.stderr)
            return 1
    if result is None:
        print(f"claude-sdk-run: no result message received; session {session}", file=sys.stderr)
        return 1

    if a.json:
        body = json.dumps({
            "is_error": result.is_error, "subtype": result.subtype, "result": result.result,
            "total_cost_usd": result.total_cost_usd, "num_turns": result.num_turns,
            "session_id": result.session_id, "duration_ms": result.duration_ms,
            "stop_reason": result.stop_reason, "usage": result.usage, "model": a.model, "effort": a.effort,
        }, indent=2)
    else:
        body = result.result or ""
    if a.out:
        Path(a.out).write_text(body + "\n", encoding="utf-8")
    else:
        sys.stdout.write(body + "\n")
    cost = f"${result.total_cost_usd:.4f}" if result.total_cost_usd is not None else "n/a"
    print(f"claude-sdk-run: {result.subtype}, {result.num_turns} turns, cost {cost}, session {result.session_id}",
          file=sys.stderr)
    return 1 if result.is_error else 0


def main(argv: list[str]) -> int:
    # Windows pipes default to the ANSI code page; prompts and results are UTF-8 (a leading BOM is dropped).
    sys.stdin.reconfigure(encoding="utf-8-sig")
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    a = parse_args(argv)
    key, workspace = read_env_file(Path(os.environ.get("CLAUDE_API_ENV_FILE") or HERE / ".env.claude"))
    clean_environment(key, workspace)
    try:
        return asyncio.run(run(a))
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
