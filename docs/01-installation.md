# 01. Установка

## Что происходит

Скрипт `setup-codex.sh` устанавливает Node.js и Codex CLI автоматически.

## Node.js

- Если Homebrew есть — `brew install node@22`
- Если нет — скачивается напрямую в `~/.node/` без sudo
- Минимальная версия: v20
- Путь добавляется в `~/.zshrc`

## Codex CLI

- Пакет: `@openai/codex`
- Устанавливается глобально: `npm install -g @openai/codex@latest`
- Команда запуска: `codex`

## Ручная установка

Если скрипт не сработал:

```bash
# Node.js через Homebrew
brew install node@22

# Или напрямую (Apple Silicon)
curl -fL https://nodejs.org/dist/v22.15.0/node-v22.15.0-darwin-arm64.tar.gz | tar xz -C ~/.node --strip-components=1
echo 'export PATH="$HOME/.node/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Codex CLI
npm install -g @openai/codex@latest
```

## Проверка

```bash
node --version    # v22.x.x
codex --version   # должна быть версия
```
