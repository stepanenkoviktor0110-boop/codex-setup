#!/bin/bash
set -euo pipefail

# Full Codex CLI setup for macOS
# Installs Node.js, Codex CLI, API key, user profile, safety hooks, Agent Cleaner, methodology

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CODEX_DIR="$HOME/.codex"
AGENTS_DIR="$HOME/.agents"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
step() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

# Fix bracketed paste (prevents ~0/~1 artifacts in some terminals)
printf '\e[?2004l'

# ─── Step 1: Node.js ────────────────────────────────────────

step "Шаг 1/7: Node.js"

install_node() {
    if command -v brew &>/dev/null; then
        echo "Устанавливаю через Homebrew..."
        brew install node@22
        ok "Node.js установлен через Homebrew"
    else
        echo "Homebrew не найден. Скачиваю Node.js напрямую..."
        ARCH=$(uname -m)
        if [ "$ARCH" = "arm64" ]; then
            NODE_URL="https://nodejs.org/dist/v22.15.0/node-v22.15.0-darwin-arm64.tar.gz"
        else
            NODE_URL="https://nodejs.org/dist/v22.15.0/node-v22.15.0-darwin-x64.tar.gz"
        fi
        NODE_DIR="$HOME/.node"
        rm -rf "$NODE_DIR"
        mkdir -p "$NODE_DIR"
        echo "Скачиваю Node.js v22 ($ARCH)... (~45MB, подожди 1-2 минуты)"
        curl -fL --progress-bar "$NODE_URL" | tar xz -C "$NODE_DIR" --strip-components=1
        export PATH="$NODE_DIR/bin:$PATH"
        SHELL_RC="$HOME/.zshrc"
        if ! grep -q '.node/bin' "$SHELL_RC" 2>/dev/null; then
            echo '' >> "$SHELL_RC"
            echo '# Node.js (installed by codex-setup)' >> "$SHELL_RC"
            echo 'export PATH="$HOME/.node/bin:$PATH"' >> "$SHELL_RC"
        fi
        if command -v node &>/dev/null; then
            ok "Node.js $(node --version) установлен в $NODE_DIR"
        else
            fail "Не удалось установить Node.js. Скачай вручную: https://nodejs.org/"
        fi
    fi
}

if command -v node &>/dev/null && command -v npm &>/dev/null; then
    NODE_VER=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge 20 ]; then
        ok "Node.js $NODE_VER уже установлен"
    else
        warn "Node.js $NODE_VER слишком старый (нужен v20+)"
        install_node
    fi
else
    if command -v node &>/dev/null && ! command -v npm &>/dev/null; then
        warn "Node.js найден, но npm отсутствует. Переустанавливаю..."
    else
        echo "Node.js не найден. Устанавливаю..."
    fi
    install_node
fi

# ─── Step 2: Codex CLI ──────────────────────────────────────

step "Шаг 2/7: Codex CLI"

# Ensure npm global prefix is writable without sudo.
# Reliably detect write access by attempting to create a temp file in the
# prefix's lib dir (macOS ACL can make `test -w` lie). If not writable,
# switch prefix to ~/.npm-global and add it to PATH.
NPM_GLOBAL="$HOME/.npm-global"

npm_prefix_is_writable() {
    local prefix="$1"
    [ -z "$prefix" ] && return 1
    local lib_dir="$prefix/lib/node_modules"
    [ -d "$lib_dir" ] || lib_dir="$prefix"
    local probe="$lib_dir/.codex-setup-write-probe.$$"
    if ( : > "$probe" ) 2>/dev/null; then
        rm -f "$probe"
        return 0
    fi
    return 1
}

switch_npm_prefix_to_home() {
    mkdir -p "$NPM_GLOBAL"
    npm config set prefix "$NPM_GLOBAL"
    export PATH="$NPM_GLOBAL/bin:$PATH"
    local SHELL_RC="$HOME/.zshrc"
    if ! grep -q '.npm-global/bin' "$SHELL_RC" 2>/dev/null; then
        echo '' >> "$SHELL_RC"
        echo '# npm global prefix (configured by codex-setup)' >> "$SHELL_RC"
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$SHELL_RC"
    fi
    ok "npm префикс переключён на $NPM_GLOBAL"
}

CURRENT_PREFIX="$(npm prefix -g 2>/dev/null || echo '')"
if ! npm_prefix_is_writable "$CURRENT_PREFIX"; then
    warn "npm глобальный префикс ($CURRENT_PREFIX) недоступен для записи."
    echo "Переключаю префикс на $NPM_GLOBAL (без sudo)..."
    switch_npm_prefix_to_home
fi

# If codex is already installed in a non-writable system prefix (e.g. after
# an earlier `sudo npm install -g`), remove it so we can reinstall cleanly
# into the writable prefix.
if command -v codex &>/dev/null; then
    CODEX_BIN="$(command -v codex)"
    CODEX_ROOT="$(cd "$(dirname "$CODEX_BIN")/.." && pwd)"
    if [ "$CODEX_ROOT" != "$NPM_GLOBAL" ] && ! npm_prefix_is_writable "$CODEX_ROOT"; then
        warn "Codex CLI установлен в системной папке ($CODEX_ROOT) — удаляю через sudo, чтобы переустановить без sudo."
        sudo npm uninstall -g @openai/codex 2>/dev/null || true
        hash -r 2>/dev/null || true
    fi
fi

if command -v codex &>/dev/null; then
    ok "Codex CLI уже установлен ($(codex --version 2>/dev/null || echo 'version unknown'))"
    echo "Обновляю до последней версии..."
    npm install -g @openai/codex@latest
    ok "Codex CLI обновлён"
else
    echo "Устанавливаю Codex CLI..."
    npm install -g @openai/codex@latest
    ok "Codex CLI установлен"
fi

# ─── Step 3: OAuth авторизация ───────────────────────────────

step "Шаг 3/7: Авторизация (ChatGPT)"

mkdir -p "$CODEX_DIR"
CONFIG_FILE="$CODEX_DIR/config.toml"
AUTH_FILE="$CODEX_DIR/auth.json"

# Write config.toml with model if not exists
if [ -f "$CONFIG_FILE" ]; then
    if ! grep -q '^model' "$CONFIG_FILE" 2>/dev/null; then
        echo '' >> "$CONFIG_FILE"
        echo 'model = "gpt-5.4"' >> "$CONFIG_FILE"
        ok "Модель gpt-5.4 добавлена в config.toml"
    else
        ok "config.toml уже настроен"
    fi
else
    cat > "$CONFIG_FILE" << 'TOML'
# Codex CLI configuration
# Docs: https://developers.openai.com/codex/config-reference

model = "gpt-5.4"
TOML
    ok "Создан config.toml (модель: gpt-5.4)"
fi

# Check if already authenticated
if [ -f "$AUTH_FILE" ]; then
    ok "Авторизация уже выполнена ($AUTH_FILE)"
else
    echo ""
    echo "Codex CLI работает через подписку ChatGPT (Plus, Pro, Business, Edu)."
    echo "Сейчас откроется браузер для входа в аккаунт OpenAI."
    echo ""
    echo -e "${YELLOW}⚠ Нужна активная подписка ChatGPT Plus ($20/мес) или Pro ($200/мес).${NC}"
    echo "  Подробнее: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan"
    echo ""
    read -rp "Нажми Enter, чтобы открыть браузер для входа... " _

    if codex login 2>/dev/null; then
        ok "Авторизация прошла успешно"
    else
        warn "Авторизация не завершена. Запусти позже: codex login"
    fi
fi

# ─── Step 4: User Profile ───────────────────────────────────

step "Шаг 4/7: Профиль пользователя"

mkdir -p "$AGENTS_DIR"
AGENTS_MD="$AGENTS_DIR/AGENTS.md"

if [ -f "$AGENTS_MD" ] && grep -q "## User Profile" "$AGENTS_MD"; then
    ok "Профиль уже заполнен в $AGENTS_MD"
else
    echo ""
    echo "Ответь на 6 вопросов — это поможет агенту общаться с тобой эффективнее."
    echo "Просто напиши ответ и нажми Enter."
    echo ""

    read -rp "1. Кем ты работаешь / чем занимаешься? " ROLE
    echo ""
    echo "2. Приходилось ли писать код или работать с терминалом?"
    echo "   a) Нет, никогда"
    echo "   b) Пробовал немного"
    echo "   c) Использую регулярно"
    read -rp "   Ответ (a/b/c): " CODE_EXP
    case "$CODE_EXP" in
        a|A) CODE_EXP_TEXT="Не писал код и не работал с терминалом" ;;
        b|B) CODE_EXP_TEXT="Немного пробовал писать код или работать с терминалом" ;;
        c|C) CODE_EXP_TEXT="Регулярно пишет код и работает с терминалом" ;;
        *)   CODE_EXP_TEXT="$CODE_EXP" ;;
    esac

    echo ""
    echo "3. Какие продукты хочешь создавать с помощью агента?"
    echo "   (боты, сайты, приложения, аналитика данных, автоматизация, другое)"
    read -rp "   Ответ: " GOALS

    echo ""
    echo "4. В какой сфере планируешь применять агента?"
    echo "   (работа, учёба, хобби, фриланс, свой бизнес, другое)"
    read -rp "   Ответ: " DOMAIN

    echo ""
    echo "5. Как предпочитаешь получать ответы?"
    echo "   a) Кратко и по делу"
    echo "   b) С объяснениями"
    echo "   c) Пошагово, как для новичка"
    read -rp "   Ответ (a/b/c): " STYLE
    case "$STYLE" in
        a|A) STYLE_TEXT="Кратко и по делу, без лишних объяснений" ;;
        b|B) STYLE_TEXT="С объяснениями ключевых моментов" ;;
        c|C) STYLE_TEXT="Пошагово, подробно, как для новичка" ;;
        *)   STYLE_TEXT="$STYLE" ;;
    esac

    echo ""
    echo "6. На каком языке общаться?"
    echo "   a) Русский"
    echo "   b) English"
    echo "   c) Оба"
    read -rp "   Ответ (a/b/c): " LANG
    case "$LANG" in
        a|A) LANG_TEXT="Русский" ;;
        b|B) LANG_TEXT="English" ;;
        c|C) LANG_TEXT="Русский и English (оба)" ;;
        *)   LANG_TEXT="$LANG" ;;
    esac

    PROFILE_BLOCK="
## User Profile

- **Роль:** ${ROLE}
- **Опыт с кодом:** ${CODE_EXP_TEXT}
- **Цели:** ${GOALS}
- **Сфера:** ${DOMAIN}
- **Стиль общения:** ${STYLE_TEXT}
- **Язык:** ${LANG_TEXT}"

    # Copy full AGENTS.md from methodology if not present yet
    if [ ! -f "$AGENTS_MD" ]; then
        if [ -f "$REPO_DIR/configs/AGENTS.md" ]; then
            cp "$REPO_DIR/configs/AGENTS.md" "$AGENTS_MD"
            ok "AGENTS.md скопирован из методологии (полная версия)"
        else
            printf '%s\n' "# Global Preferences" > "$AGENTS_MD"
            warn "Шаблон AGENTS.md не найден, создан минимальный"
        fi
    fi

    # Append user profile
    printf '%s\n' "$PROFILE_BLOCK" >> "$AGENTS_MD"

    ok "Профиль сохранён в $AGENTS_MD"
fi

# ─── Step 5: Safety Hooks ───────────────────────────────────

step "Шаг 5/7: Безопасность"

bash "$SCRIPT_DIR/install-hooks.sh"

# ─── Step 6: Agent Cleaner ──────────────────────────────────

step "Шаг 6/7: Agent Cleaner"

CLEANER_PATH="$HOME/agent_cleaner.py"
CLEANER_LOG="$HOME/agent_cleaner.log"
PLIST_NAME="com.user.agentcleaner"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

# Copy script
cp "$REPO_DIR/scripts/agent_cleaner.py" "$CLEANER_PATH"
chmod +x "$CLEANER_PATH"
ok "Скрипт скопирован в $CLEANER_PATH"

# Create plist from template
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|AGENT_CLEANER_PATH|$CLEANER_PATH|g" \
    -e "s|AGENT_CLEANER_LOG|$CLEANER_LOG|g" \
    "$REPO_DIR/configs/com.user.agentcleaner.plist" > "$PLIST_PATH"
ok "LaunchAgent создан: $PLIST_PATH"

# Load service
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi
launchctl load "$PLIST_PATH"
ok "Agent Cleaner запущен (проверяет каждые 60 сек)"

# ─── Step 7: Methodology (Skills + Agents) ──────────────────

step "Шаг 7/7: Методология (Skills + Agents)"

SKILLS_DIR="$AGENTS_DIR/skills"
AGENTS_DEST="$AGENTS_DIR/agents"
mkdir -p "$SKILLS_DIR"
mkdir -p "$AGENTS_DEST"

# Copy skills
if [ -d "$REPO_DIR/skills" ]; then
    SKILL_COUNT=0
    for skill_dir in "$REPO_DIR/skills"/*/; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            cp -r "$skill_dir" "$SKILLS_DIR/"
            SKILL_COUNT=$((SKILL_COUNT + 1))
        fi
    done
    ok "Скопировано skills: $SKILL_COUNT"
else
    warn "Папка skills/ не найдена в репозитории"
fi

# Copy agents
if [ -d "$REPO_DIR/agents" ]; then
    AGENT_COUNT=0
    for agent_file in "$REPO_DIR/agents"/*.md; do
        if [ -f "$agent_file" ]; then
            cp "$agent_file" "$AGENTS_DEST/"
            AGENT_COUNT=$((AGENT_COUNT + 1))
        fi
    done
    ok "Скопировано agents: $AGENT_COUNT"
else
    warn "Папка agents/ не найдена в репозитории"
fi

# Copy shared resources if present
if [ -d "$REPO_DIR/shared" ]; then
    SHARED_DIR="$AGENTS_DIR/shared"
    mkdir -p "$SHARED_DIR"
    cp -r "$REPO_DIR/shared"/* "$SHARED_DIR/" 2>/dev/null || true
    ok "Скопированы shared-ресурсы"
fi

# ─── Done ────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}=== Готово! ===${NC}"
echo ""
echo "Что установлено:"
echo "  ✓ Node.js $(node --version)"
echo "  ✓ Codex CLI (запуск: codex)"
echo "  ✓ Авторизация ChatGPT (OAuth)"
echo "  ✓ Профиль пользователя ($AGENTS_MD)"
echo "  ✓ Защитные хуки (опасные команды заблокированы)"
echo "  ✓ Agent Cleaner (launchd, лог: $CLEANER_LOG)"
echo "  ✓ Методология: skills + agents"
echo ""
echo "Запусти Codex:"
echo "  codex"
echo ""
echo -e "${YELLOW}⚠ Если что-то не работает — перезапусти терминал или выполни: source ~/.zshrc${NC}"
