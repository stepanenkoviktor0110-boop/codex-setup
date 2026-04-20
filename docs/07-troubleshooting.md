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

Чаще всего — `~/.npm-global/bin` не в PATH в текущей сессии (скрипт прописывает это в `.zshrc`, но старый терминал не перечитал файл):

```bash
source ~/.zshrc
which codex
```

Должен показать `~/.npm-global/bin/codex`. Если нет — переустанови:

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g @openai/codex@latest
```

## Ошибка `EACCES` при `npm install -g`

Node стоит в системной папке (`/usr/local`), и npm не может туда писать без root. **Не делай `sudo npm install`** — после этого файлы в `~/.npm` станут root-owned и сломают все последующие установки.

Правильный фикс — запусти `bash scripts/setup-codex.sh`, он всё сделает сам: переключит префикс на `~/.npm-global`, починит кэш `~/.npm`, удалит старую системную установку (если была).

Вручную то же самое:

```bash
sudo chown -R $(id -u):$(id -g) ~/.npm ~/.npm-global 2>/dev/null
sudo rm -rf /usr/local/lib/node_modules/@openai /usr/local/lib/node_modules/codex-cli /usr/local/bin/codex
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
npm install -g @openai/codex@latest
```

## Авторизация не работает

```bash
# Попробуй device auth
codex login --device-auth

# Проверь подписку на https://chatgpt.com/settings
```

### `Country, region, or territory not supported`

OpenAI блокирует IP из РФ, Беларуси и ряда других стран. Включи системный VPN с выходом в США/ЕС, проверь регион:

```bash
curl -s https://ipinfo.io/country
```

Если вернулось `RU` — VPN не поднят или маршрутизирует не весь трафик. После нормального региона — `codex login` заново. Подробнее — в [02-auth.md](02-auth.md#регион-и-vpn).

## Ошибка `unknown variant 'full-auto'` в config.toml

В новой версии Codex CLI значение `approval_policy = "full-auto"` больше не валидно. Замени в `~/.codex/config.toml`:

```toml
approval_policy = "never"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
```

Что это даёт:
- `approval_policy = "never"` — Codex не спрашивает разрешения на команды (прежний full-auto).
- `sandbox_mode = "workspace-write"` — может читать/писать в текущей папке проекта и `/tmp`, но не трогает систему.
- `network_access = true` — разрешает сети (npm install, curl, git push). Без этого будут DNS-ошибки.

Для **полной свободы** (опасно, без sandbox):

```toml
approval_policy = "never"
sandbox_mode = "danger-full-access"
```

Используй только если доверяешь происходящему — агент сможет удалить что угодно.

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
