# Infrastructure Migration Plan

<!-- LLM: Insert current date in format: YYYY-MM-DD -->
**Created:** [DATE]
**Status:** Feature branch infrastructure ready, deployment pending

---

## Current State

<!-- LLM: Describe what's configured in feature branch based on what was actually created.
List items like:
- ✅ CI/CD для тестирования (specify which jobs: lint, type-check, tests, build)
- ✅ Docker для local development (specify: dev only or dev+prod)
- ✅ Pre-commit hooks (gitleaks или другие)
- ✅ Testing infrastructure (specify framework: Vitest/pytest/etc)
- ✅ Folder structure для нового кода (src/, tests/, etc)
-->

**Feature branch (`feature/migration-ai-first`):**
[LLM: List configured infrastructure items here]

<!-- LLM: Confirm that main/dev branches were NOT touched -->
**main/dev branches:**
- ⚠️ **НЕ ТРОНУТЫ** (deployments продолжают работать)
- Существующие workflows НЕ изменены
- Production/staging работают как прежде

---

## Migration Steps

### Step 1: Рефакторинг в feature ветке

**Текущий этап:** Разработка и рефакторинг legacy кода из `old/` в новую структуру `src/`

**TODO:**
- [ ] Рефакторинг кода (используй `/new-feature` для каждой фичи)
- [ ] Покрытие тестами
- [ ] Code review
- [ ] Все тесты проходят

---

### Step 2: Merge feature → dev + Deploy Setup

**После завершения рефакторинга:**

1. **Merge feature → dev:**
   ```bash
   git checkout dev
   git merge feature/migration-ai-first
   git push origin dev
   ```

2. **Настроить deployment для dev→staging:**

<!-- LLM: Read .agents/skills/project-knowledge/references/deployment.md and fill deployment info:
- Platform (VPS/Railway/Vercel/Fly.io/etc)
- If VPS: SSH access details, server IP for staging
- If cloud platform: specify which one
- Environment name for staging
-->
   **Platform:** [LLM: Insert platform from deployment.md]

   **Staging environment:** [LLM: Insert staging env details from deployment.md]

3. **Обновить CI/CD для dev:**
   - Отредактировать `.github/workflows/ci-feature.yml` → переименовать в `ci.yml`
   - Добавить deployment job для dev branch → staging
   - Добавить GitHub secrets (см. ниже)

4. **Создать production Docker config (если ещё нет):**
   - `docker-compose.prod.yml` (multi-stage build, optimized)

5. **Протестировать на staging:**
   - Push в dev → автодеплой на staging
   - Smoke tests, integration tests
   - User acceptance testing

<!-- LLM: Read .agents/skills/project-knowledge/references/deployment.md and list required GitHub Secrets.
Format as markdown list with secret names and descriptions.
Example:
- SSH_PRIVATE_KEY - для деплоя на VPS
- SERVER_IP_STAGING - IP адрес staging сервера
- DATABASE_URL - connection string для staging БД
-->
**GitHub Secrets для добавления (Settings → Secrets → Actions):**

[LLM: List required secrets from deployment.md here]

---

### Step 3: Merge dev → main (Production)

**⚠️ ТОЛЬКО после полного тестирования на staging!**

1. **Убедись что staging работает стабильно:**
   - [ ] Нет критичных багов
   - [ ] Performance приемлемый
   - [ ] User acceptance testing пройден

2. **Merge dev → main:**
   ```bash
   git checkout main
   git merge dev
   git push origin main
   ```

3. **Настроить deployment main→production:**
   - Обновить `.github/workflows/ci.yml`
   - Добавить deployment job для main branch → production
   - Добавить production secrets в GitHub

<!-- LLM: Read .agents/skills/project-knowledge/references/deployment.md and suggest appropriate deployment strategy.
Consider project size, traffic, downtime tolerance.
Default for small projects: simple deployment
For larger projects: suggest blue-green or canary
-->
4. **Deployment strategy:**

   [LLM: Recommend deployment strategy based on project from deployment.md]

   - [ ] Blue-green deployment (zero downtime, requires 2x resources)
   - [ ] Canary release (постепенный rollout, сложнее)
   - [ ] Rolling deployment (обновление по одному instance)
   - [ ] Simple deployment (маленькие проекты, короткий downtime ok)

<!-- LLM: Read .agents/skills/project-knowledge/references/deployment.md and suggest monitoring setup.
Include what monitoring tools/services are mentioned or recommend appropriate ones.
-->
5. **Мониторинг после deploy:**

   [LLM: List monitoring setup from deployment.md or suggest appropriate tools]

   - [ ] Health checks
   - [ ] Error tracking
   - [ ] Performance monitoring
   - [ ] Logs

---

## Rollback Plan

<!-- LLM: Read .agents/skills/project-knowledge/references/deployment.md for rollback procedures.
If not specified there, provide standard git-based rollback for the platform.
-->

**IF что-то пошло не так на staging:**
- `git revert` проблемного коммита в dev
- Push в dev → автодеплой исправления

**IF что-то пошло не так на production:**

[LLM: Insert rollback procedure from deployment.md, or provide platform-specific default]

---

## Notes

- 📝 Этот документ обновляется по мере прогресса миграции
- ⚠️ main branch НЕ ТРОГАТЬ до готовности!
- ✅ Текущая infrastructure (main/dev) продолжает работать
