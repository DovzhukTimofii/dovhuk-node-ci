# Ohm Lab

Вебкалькулятор сили струму та потужності для резистивного кола постійного струму.

**Довжук Тимофій Андрійович · КН-41**

## Можливості

- Вебінтерфейс українською мовою та HTTP API.
- Розрахунок за законом Ома з перевіркою вхідних даних.
- PostgreSQL та перевірка готовності застосунку.
- Docker Compose для локального запуску.
- GitHub Actions для тестування та збірки.
- Конфігурація Terraform і автоматизований деплой на AWS EC2.

## Документація

[Структура, локальний запуск, API та розгортання](students/dovzhuk-timofii/README.md).

Код розміщено в `students/dovzhuk-timofii/`.
Workflow — `.github/workflows/ci.yml`.

Деплой увімкнений лише за repository variable `ENABLE_DEPLOY=true`.
Без цієї змінної виконується тільки CI.

Структура базується на [devops-template](https://github.com/Max-K44/devops-template).
