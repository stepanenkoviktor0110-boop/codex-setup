# 02. Авторизация

## Как работает

Codex CLI использует OAuth — вход через аккаунт ChatGPT в браузере. API-ключ не нужен.

## Требования

Активная подписка ChatGPT:
- **Plus** — $20/мес
- **Pro** — $200/мес
- **Business / Edu / Enterprise** — тоже поддерживаются

Подробнее: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan

## Что делает скрипт

1. Запускает `codex login`
2. Открывается браузер — входишь в аккаунт OpenAI
3. Токен сохраняется в `~/.codex/auth.json`

## Ручная авторизация

```bash
codex login
```

Или через device code (если браузер не открывается):

```bash
codex login --device-auth
```

## Проверка

```bash
codex   # если запускается без ошибок авторизации — всё ок
```

## Переавторизация

Если токен протух:

```bash
codex login
```
