# Triad Index

Unified index of all methodology knowledge — reasoning patterns and operational lessons.
One line per unique triad. Source of truth for similarity matching and Seen counters.

| # | Trigger | Action | Goal | Scope | Seen | Section |
|---|---------|--------|------|-------|------|---------|
| 1 | изменение сигнатуры функции-callback | запустить build до коммита | не ломать deploy из-за type error | universal | 2 | Universal |
| 2 | generic retry decorator оборачивает API-вызов | явно исключить non-retryable exceptions | не ретраить ошибки, которые повторятся всегда | universal | 1 | Universal |
| 3 | генерация задач из tech-spec | проверять каждый путь через test -e, валидировать depends_on | предотвратить задачи с несуществующими файлами | universal | 1 | Universal |
| 4 | AC для markdown-only фич | формулировать через наличие конкретных артефактов | сделать AC автоматически проверяемыми | universal | 1 | Universal |
| 5 | spawn wave с >4 агентами | batch по 4, close all before next batch | предотвратить OOM и index.lock на хосте | situational | 1 | Situational |
| 6 | агент предлагает cherry-pick между framework и project repo | отклонить, framework обновлять только через git pull | не создавать merge-конфликты в несуществующих файлах | situational | 1 | Situational |
| 7 | конфигурация моделей для multi-agent workflow | один tier = одна модель, без fallbacks | не маскировать использование неправильной модели | situational | 1 | Situational |
| 8 | ревью нашло паттерн ошибки (не разовый баг) | добавить предупреждение в промт следующего teammate | предотвратить повторение ошибки в следующих задачах | situational | 1 | Situational |
| 9 | написание тестов в multi-agent workflow | требовать assertion на результат функции, не только на mock | тесты ловят баги, а не проверяют форму вызова | situational | 1 | Situational |
| 10 | security/code audit в multi-task feature | вести known-issues.md, аудитор читает перед ревью | не тратить время на повторный репорт известных проблем | situational | 1 | Situational |
