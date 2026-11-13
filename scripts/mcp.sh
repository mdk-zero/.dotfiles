#!/bin/bash

# Spec Kit CLI (provides `specify mcp`). Installed from GitHub, not PyPI:
# the PyPI `specify-cli` is not the Spec Kit project.
pipx install --force "git+https://github.com/github/spec-kit.git@v1.4.0"

# User scope = available in every project. Remove first so reruns don't fail.
add() {
  claude mcp remove --scope user "$1" >/dev/null 2>&1
  claude mcp add --scope user "$@"
}

add shadcn -- npx shadcn@latest mcp
add playwright -- npx @playwright/mcp@latest --browser chromium
add specify -- "$HOME/.local/bin/specify" mcp
add supabase --transport http https://mcp.supabase.com/mcp

npx -y playwright install chromium

echo "Run /mcp inside Claude Code and pick supabase to sign in."
