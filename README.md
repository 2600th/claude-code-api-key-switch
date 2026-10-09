# Claude Code API Key Switch

**Run Claude Code on your own Anthropic API key, per terminal, without logging out of your subscription.**

- 🎁 **Spend your Claude Max or Team monthly API credits** ($100–$500) on headless Claude Code runs, with a hard spending cap.
- 🔁 **Hit your usage limit?** Keep the same conversation going on your API key with `claude-api --continue`.
- 🪟 Windows (PowerShell, cmd, Git Bash), macOS and Linux. No install, just a few small scripts.

Your normal `claude` command and the desktop app keep using your subscription.

---

## 🧭 Which option is right for me?

| Your situation | Best option |
|---|---|
| You have **Max or Team** and want to use the **monthly API credits** | ✅ `claude-api-run` (this repo) |
| You hit your limit and have **prepaid Console credit or a company API key** | ✅ `claude-api` (this repo) |
| You hit your limit and just want the simplest fix | Claude Code's built-in **`/usage-credits`**. No repo needed. |

> ⚠️ **Max/Team API credits do NOT cover interactive Claude Code.** They cover headless `claude -p` runs, which is what `claude-api-run` does. Interactive `claude-api` is charged to credit you **bought** in the Console. [Details below](#-using-your-max-or-team-api-credits).

---

## ✅ What you need

- [Claude Code](https://code.claude.com/docs) installed (the `claude` command works)
- An API key from the [Claude Console](https://platform.claude.com) → **API Keys**
- Credit on that Console account: your Max/Team monthly credits, or credit you bought (**Settings → Billing**)

---

## 🚀 Setup (Windows, about 2 minutes)

1. **Download** this repo:
   ```powershell
   git clone https://github.com/2600th/claude-code-api-key-switch.git
   ```
   Or click **Code → Download ZIP** and unzip it.
2. **Double-click `setup.cmd`** in the folder. It will:
   - ask for your key (hidden while you paste it)
   - save it to a private `.env.claude` file
   - add the folder to your PATH
   - check that everything works
3. **Open a new terminal.** Done.

> Look for `READY` at the end of setup. If you see `NOT READY`, read the line above it, or see [Troubleshooting](#-troubleshooting).

<details>
<summary><b>Setup on macOS / Linux / Git Bash</b></summary>

```bash
git clone https://github.com/2600th/claude-code-api-key-switch.git ~/claude-api
cd ~/claude-api
cp .env.claude.example .env.claude      # then open .env.claude and paste your key
chmod 600 .env.claude                   # only you can read it
chmod +x claude-api claude-api-run claude-api-check
echo 'export PATH="$PATH:$HOME/claude-api"' >> ~/.bashrc   # or ~/.zshrc
```
Open a new terminal, then check it:
```bash
claude-api-check --online
```
</details>

<details>
<summary><b>Manual setup on Windows (without setup.cmd)</b></summary>

1. Copy `.env.claude.example` to `.env.claude` and paste your key in it.
2. Add this folder to your PATH. Run this **inside the folder** in PowerShell:
   ```powershell
   [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path','User') + ';' + (Get-Location).Path, 'User')
   ```
3. Open a new terminal and run `claude-api-check -Online`.
</details>

---

## 🎁 Using your Max or Team API credits

Since October 2026, Max and Team plans include monthly credits for the Claude API.

| Plan | Credit per month |
|---|---|
| Max 5x | $100 |
| Max 20x | $200 |
| Team | $20 per Standard seat, $100 per Premium seat (up to $500 in total) |

**Claim them once:**
1. On [claude.ai](https://claude.ai) in a browser: **Settings → Billing → API credits**.
2. **Link** a Console organization. You can't change it later without contacting support.
3. In that organization, create an API key. **Use that key in setup.**

**What the credits pay for:**

| Command | Paid by the credits? |
|---|---|
| `claude-api-run` (headless `claude -p`) | ✅ Yes |
| `claude-api` (interactive chat) | ❌ No. Uses credit you bought. |

- Credits **expire each month**. No rollover.
- When they run out, requests stop. You are **never** charged on your Claude plan.
- Start `claude-api-run` from a **normal terminal**. Anthropic counts `-p` runs started by an IDE extension, the desktop app or the GitHub Action as Claude Code, which the credits don't cover.

📖 Official details: [API credits for Max and Team plans](https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers)

---

## 🤖 Headless runs: `claude-api-run`

Gives Claude **one task, with no chat window**, then stops. Good for scripts, batch jobs, or handing work to a "subagent".

```powershell
claude-api-run -PromptFile task.md -OutFile result.md -MaxBudgetUsd 3
```

- 🛑 **`-MaxBudgetUsd` is a hard spending cap.** Default: $5.
- 🧪 Test first with `-DryRun`. It shows what would run and spends nothing.
- 📄 Write the task in `task.md`, and read the answer in `result.md`.

<details>
<summary><b>All options</b></summary>

| Option (PowerShell) | Bash | What it does | Default |
|---|---|---|---|
| `-Prompt "..."` | (stdin) | The task, as text | — |
| `-PromptFile task.md` | `< task.md` | The task, from a file | — |
| `-OutFile result.md` | `-o result.md` | Save the answer to a file | print it |
| `-Model` | `-m` | Full model ID | `claude-sonnet-5-5` |
| `-MaxBudgetUsd` | `-b` | Spending cap in USD | `5` |
| `-MaxTurns` | `-t` | Max steps | `40` |
| `-PermissionMode` | `-p` | What Claude may do without asking | `acceptEdits` |
| `-Cwd C:\repo` | `-C /c/repo` | Folder to work in | current folder |
| `-Json` | `-j` | JSON output (includes cost and session ID) | text |
| `-Bare` | `-B` | Skip CLAUDE.md, hooks and plugins (cheaper start) | off |
| `-AddDir`, `-AllowedTools`, `-AppendSystemPrompt` | — | Passed to `claude` | — |
| `-DryRun` | — | Show the command, spend nothing | off |

Bash example:
```bash
claude-api-run -m claude-sonnet-5-5 -b 3 -o result.md < task.md
```

- Use `-PermissionMode bypassPermissions` **only** in a sandbox. It lets Claude do anything without asking.
- The exit code is Claude's own exit code.
- To reopen a headless run as a chat: `claude-api --resume <session ID from the JSON>`.
</details>

<details>
<summary><b>Cost tips</b></summary>

- **Every new run has a start-up cost.** Claude Code loads its system prompt and tools first. Even a one-word answer on Haiku cost about **$0.08**.
- So **budgets under ~$0.25 can stop a run before it answers.**
- `-Bare` cuts the start-up cost. Put all the context the task needs in the prompt.
- **Use full model IDs**: `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-4-5-20251001`. Short names like `haiku` can point to older models.
</details>

---

## 🔁 Interactive: `claude-api`

You hit the usage limit mid-task. Now:

```powershell
claude-api --continue
```

That picks up **the same conversation**, now billed to your API key.

| I want to… | Type |
|---|---|
| Continue my last conversation | `claude-api --continue` |
| Pick an older conversation | `claude-api --resume` |
| Start a new conversation | `claude-api` |
| Go back to my subscription | exit, then type `claude` |

- Run these inside your project folder, the same place you'd run `claude`.
- Any normal `claude` option works, e.g. `claude-api --model claude-opus-5-5`.
- 💳 This uses **credit you bought** in the Console, not your Max/Team monthly credits.

### ⚠️ First time only

Claude Code asks: **"Do you want to use this API key?"**

→ Choose **Yes**.

Type `/status` inside Claude Code to see which login is active.

---

## 🔒 Is my key safe?

- Your key lives in **one file**: `.env.claude`, in this folder.
- **Git ignores it**, so it can't be committed by accident.
- The scripts **never print it**, not even in error messages.
- The key goes only to the one `claude` process the script starts. Nothing else on your computer sees it.

> 🚫 Never paste your key into a chat, an issue, or a screenshot. If it leaks, delete it in the Console and make a new one.

---

## 🩺 Troubleshooting

| You see | Fix |
|---|---|
| `key file not found` | Run `setup.cmd`, or copy `.env.claude.example` to `.env.claude` and add your key. |
| `'claude-api' is not recognized` | Open a **new** terminal. Still broken? The folder isn't on your PATH. Run `setup.cmd` again. |
| `running scripts is disabled on this system` | Run `setup.cmd` once. It allows local scripts for your user. |
| `Credit balance too low` in `claude-api` | Normal if your Console only has Max/Team credits: they don't cover interactive Claude Code. Buy credit (Console → **Settings → Billing**), or use `claude-api-run`. |
| `Credit balance is too low` in `claude-api-run` | This month's credits are used up. Wait for next month, or buy credit. |
| `HTTP 400` with a key starting `sk-ant-usr` | This key type needs a workspace ID. Add `ANTHROPIC_WORKSPACE_ID=wrkspc_...` to `.env.claude`. Find it at Console → **Settings → Workspaces**. |
| `HTTP 401` | The key is wrong or deleted. Make a new one in the Console. |
| `/status` still shows your subscription | You answered **No** to "use this API key?". Inside `claude-api`, type `/config` and turn on **Use custom API key**. |

**Health check** (free, uses no tokens):
```powershell
claude-api-check -Online       # Windows
claude-api-check --online      # macOS / Linux / Git Bash
```

---

## ❓ FAQ

**Does Claude Code do this by itself?**
Partly. When you hit a limit, the built-in `/usage-credits` lets you pay API prices with credit bought on claude.ai. It can't use a Console API key, and it can't spend your Max/Team API credits. Claude Code has no built-in switch to an API key.

**Is this allowed?**
Yes. Anthropic's docs allow using your own API key, billed to you, alongside a subscription. See [Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance).

**Does it switch back automatically?**
No. Each terminal stays on the login it started with. Type `claude` to go back to your subscription. Want automatic switching? Try [claude-switch](https://www.npmjs.com/package/@sirtheo/claude-switch) or [CC Switch](https://github.com/farion1231/cc-switch).

**Do I lose my conversation when I switch?**
No. Conversations are saved on your computer, so `claude-api --continue` picks up where `claude` stopped. The first reply after switching re-reads the whole conversation, so it costs a bit more.

---

## 📁 What's in this folder

| File | What it is |
|---|---|
| `setup.cmd` | **Start here (Windows).** Double-click to set up. |
| `claude-api-run` | Headless runs with a spending cap. Max/Team credits apply. |
| `claude-api` | Interactive Claude Code on your API key. |
| `claude-api-check` | Check your key and setup. |
| `.env.claude.example` | Template for your key file. |
| `.env.claude` | 🔒 **Your key.** Created by setup. Private. |
| `lib.ps1`, `lib.sh` | Shared code the other scripts use. |

Each command comes in three forms: `.ps1` (PowerShell), `.cmd` (cmd) and no extension (bash). Just type the name and the right one runs.

<details>
<summary><b>Advanced settings</b></summary>

- Keep your key file somewhere else: set the environment variable `CLAUDE_API_ENV_FILE` to its full path.
- `ANTHROPIC_WORKSPACE_ID` can also come from the environment instead of the file.
</details>

---

<sub>Not affiliated with Anthropic. "Claude" and "Claude Code" are Anthropic's trademarks. Plans, credits and prices change, so check the linked Anthropic pages for the latest.</sub>
