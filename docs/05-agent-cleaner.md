# 05. Agent Cleaner

## Проблема

Codex CLI запускает Node.js-процессы. Иногда они зависают — родительский процесс завершился, а дочерние остались. Через несколько часов работы таких «зомби» может накопиться десятки, и они забивают оперативную память.

## Решение

Agent Cleaner — Python-скрипт, который работает в фоне и автоматически убивает зависшие процессы.

### Логика работы

1. Каждые 60 секунд проверяет использование RAM
2. Если RAM > 80% — ищет Node.js-процессы, у которых:
   - Родительский процесс мёртв (orphaned)
   - Работают дольше 2 минут (не убивает свежие)
3. Убивает найденных зомби (SIGTERM, потом SIGKILL)

### Файлы

- `~/agent_cleaner.py` — сам скрипт
- `~/agent_cleaner.log` — лог работы
- `~/Library/LaunchAgents/com.user.agentcleaner.plist` — сервис launchd

### Как проверить, что работает

```bash
# Статус сервиса
launchctl list | grep agentcleaner

# Посмотреть лог
tail -20 ~/agent_cleaner.log
```

### Как остановить

```bash
launchctl unload ~/Library/LaunchAgents/com.user.agentcleaner.plist
```

### Как запустить снова

```bash
launchctl load ~/Library/LaunchAgents/com.user.agentcleaner.plist
```

### Настройки

Редактируй `~/agent_cleaner.py`:

- `CHECK_INTERVAL = 60` — интервал проверки (секунды)
- `RAM_THRESHOLD = 80` — порог RAM (%)
- `MIN_UPTIME_BEFORE_KILL = 120` — минимальное время жизни процесса (секунды)
