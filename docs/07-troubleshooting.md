# 07. Решение проблем

## Bracketed paste (символы ~0, ~1 при вставке)

```bash
printf '\e[?2004l'
```

Выполни перед вставкой команд в терминал. Скрипт делает это автоматически.

## Node.js не найден после установки

```bash
source ~/.zshrc
```

Или перезапусти терминал.

## `codex: command not found`

```bash
# Проверь, что npm bin в PATH
npm bin -g

# Переустанови
npm install -g @openai/codex@latest
```

## Авторизация не работает

```bash
# Попробуй device auth
codex login --device-auth

# Проверь подписку на https://chatgpt.com/settings
```

## Agent Cleaner не запускается

```bash
# Проверь plist
plutil ~/Library/LaunchAgents/com.user.agentcleaner.plist

# Перезагрузи
launchctl unload ~/Library/LaunchAgents/com.user.agentcleaner.plist
launchctl load ~/Library/LaunchAgents/com.user.agentcleaner.plist

# Посмотри лог
tail -50 ~/agent_cleaner.log
```

## Хуки не блокируют команды

```bash
# Проверь, что хуки включены
grep codex_hooks ~/.codex/config.toml

# Должно быть: codex_hooks = true

# Проверь, что скрипт исполняемый
ls -la ~/.codex/hooks/block-dangerous.sh
```

## Повторный запуск скрипта

Скрипт идемпотентный — безопасно запускать повторно:

```bash
cd codex-setup-main
bash scripts/setup-codex.sh
```
