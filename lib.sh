# Shared helper for the bash claude-api scripts. Source only; never prints the key.
claude_api_key() {
  local here file line
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  file="${CLAUDE_API_ENV_FILE:-$here/.env.claude}"
  [ -f "$file" ] || { echo "claude-api: key file not found: $file (copy .env.claude.example to .env.claude)" >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"; line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in ''|'#'*) continue ;; esac
    line="${line#export }"
    case "$line" in ANTHROPIC_API_KEY=*|ANTHROPIC_API_KEY:*) line="${line#ANTHROPIC_API_KEY}"; line="${line#[=:]}"; line="${line# }" ;; esac
    line="${line%\"}"; line="${line#\"}"; line="${line%\'}"; line="${line#\'}"
    case "$line" in sk-ant-*) printf '%s' "$line"; return 0 ;; esac
  done < "$file"
  echo "claude-api: no key found in $file" >&2; return 1
}

claude_workspace_id() {
  if [ -n "${ANTHROPIC_WORKSPACE_ID:-}" ]; then printf '%s' "$ANTHROPIC_WORKSPACE_ID"; return 0; fi
  local here file line
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  file="${CLAUDE_API_ENV_FILE:-$here/.env.claude}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"; line="${line#"${line%%[![:space:]]*}"}"; line="${line#export }"
    case "$line" in
      ANTHROPIC_WORKSPACE_ID=*|ANTHROPIC_WORKSPACE_ID:*)
        line="${line#ANTHROPIC_WORKSPACE_ID}"; line="${line#[=:]}"; line="${line# }"
        line="${line%\"}"; line="${line#\"}"; line="${line%\'}"; line="${line#\'}"
        printf '%s' "$line"; return 0 ;;
    esac
  done < "$file"
}

claude_api_env() {
  ANTHROPIC_API_KEY="$(claude_api_key)" || return 1; export ANTHROPIC_API_KEY
  unset CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_AUTH_TOKEN || true
  local ws line headers=""; ws="$(claude_workspace_id)"
  if [ -n "$ws" ]; then
    export ANTHROPIC_WORKSPACE_ID="$ws"
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      if ! [[ "$line" =~ ^[[:space:]]*[Aa][Nn][Tt][Hh][Rr][Oo][Pp][Ii][Cc]-[Ww][Oo][Rr][Kk][Ss][Pp][Aa][Cc][Ee]-[Ii][Dd]: ]]; then
        headers="${headers:+$headers$'\n'}$line"
      fi
    done <<< "${ANTHROPIC_CUSTOM_HEADERS:-}"
    export ANTHROPIC_CUSTOM_HEADERS="${headers:+$headers$'\n'}anthropic-workspace-id: $ws"
  else
    case "$ANTHROPIC_API_KEY" in sk-ant-usr*) echo "claude-api: user-scoped key; add ANTHROPIC_WORKSPACE_ID=wrkspc_... to the key file" >&2 ;; esac
  fi
}
