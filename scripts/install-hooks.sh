#!/bin/bash
set -euo pipefail

# Install Codex CLI safety hooks
# Writes ~/.codex/hooks.json and enables hooks in config.toml

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CODEX_DIR="$HOME/.codex"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "=== Установка защитных хуков ==="

mkdir -p "$CODEX_DIR"
mkdir -p "$CODEX_DIR/hooks"

# ─── 0. Copy hook script ────────────────────────────────────

cp "$REPO_DIR/configs/hooks/block-dangerous.sh" "$CODEX_DIR/hooks/block-dangerous.sh"
chmod +x "$CODEX_DIR/hooks/block-dangerous.sh"
ok "Скрипт блокировки скопирован в $CODEX_DIR/hooks/"

# ─── 1. Copy hooks.json ─────────────────────────────────────

HOOKS_FILE="$CODEX_DIR/hooks.json"

if [ -f "$HOOKS_FILE" ]; then
    # Merge: add our hooks without replacing existing ones
    python3 - "$HOOKS_FILE" "$REPO_DIR/configs/hooks.json" << 'PYEOF'
import json, sys

existing_path = sys.argv[1]
new_path = sys.argv[2]

with open(existing_path) as f:
    existing = json.load(f)

with open(new_path) as f:
    new = json.load(f)

# Merge each event type (PreToolUse, etc.)
for event, new_hooks in new.items():
    if event not in existing:
        existing[event] = new_hooks
        continue
    # Deduplicate by command string
    existing_commands = set()
    for hook_group in existing[event]:
        for h in hook_group.get("hooks", []):
            existing_commands.add(h.get("command", ""))
    for new_group in new_hooks:
        has_new = False
        for h in new_group.get("hooks", []):
            if h.get("command", "") not in existing_commands:
                has_new = True
        if has_new:
            existing[event].append(new_group)

with open(existing_path, 'w') as f:
    json.dump(existing, f, indent=2, ensure_ascii=False)
PYEOF
    ok "Хуки добавлены в $HOOKS_FILE (существующие сохранены)"
else
    cp "$REPO_DIR/configs/hooks.json" "$HOOKS_FILE"
    ok "Хуки установлены: $HOOKS_FILE"
fi

# ─── 2. Enable hooks + full-auto in config.toml ─────────────

CONFIG_FILE="$CODEX_DIR/config.toml"

# Use python3 to safely edit TOML without duplicating sections
python3 - "$CONFIG_FILE" << 'PYEOF'
import sys, os

config_path = sys.argv[1]
lines = []
if os.path.exists(config_path):
    with open(config_path) as f:
        lines = f.readlines()

content = ''.join(lines)

# Ensure model line exists
if 'model' not in content:
    lines.insert(0, 'model = "gpt-5.4"\n')

# Ensure approval_policy exists
if 'approval_policy' not in content:
    lines.append('\napproval_policy = "full-auto"\n')

# Ensure [features] section with codex_hooks
if 'codex_hooks' not in content:
    if '[features]' in content:
        # Add under existing [features]
        new_lines = []
        for line in lines:
            new_lines.append(line)
            if line.strip() == '[features]':
                new_lines.append('codex_hooks = true\n')
        lines = new_lines
    else:
        lines.append('\n[features]\ncodex_hooks = true\n')
elif 'codex_hooks = false' in content:
    lines = [l.replace('codex_hooks = false', 'codex_hooks = true') for l in lines]

with open(config_path, 'w') as f:
    f.writelines(lines)
PYEOF

ok "config.toml: хуки включены, режим full-auto"

echo "=== Хуки установлены ==="
echo "  Защита: опасные команды блокируются (rm -rf, curl|bash, и т.д.)"
echo "  Режим: full-auto (без подтверждений, кроме опасных)"
