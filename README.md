# CI/CD Node.js + Docker + PostgreSQL

Навчальний Node.js-проєкт для практичних занять із CI/CD, AWS EC2 та Docker.

## Реалізовано

- Node.js HTTP-застосунок на порту `3000`;
- підключення до PostgreSQL через пакет `pg`;
- `Dockerfile` на базі `node:lts`;
- `.dockerignore` для виключення `node_modules`, `.env` та службових файлів;
- `docker-compose.yml` із сервісами `app` і `db`;
- PostgreSQL 15 із persistent volume та healthcheck;
- GitHub Actions для тестування, build і Docker build;
- тегування Docker-образу коротким SHA коміту та назвою гілки;
- публікація образу в Docker Hub при наявності секретів;
- автоматичний деплой на AWS EC2 через Docker Compose;
- автоматичне видалення старих процесів PM2 перед Docker-деплоєм.

## Локальний запуск Node.js

```bash
npm install
npm start
```

Застосунок буде доступний за адресою:

```text
http://localhost:3000
```

## Docker build із тегом Git commit

Linux / Git Bash:

```bash
GIT_HASH=$(git rev-parse --short HEAD)
docker build -t dovzhuktimofii/nodeapp:$GIT_HASH .
```

PowerShell:

```powershell
$GIT_HASH = git rev-parse --short HEAD
docker build -t dovzhuktimofii/nodeapp:$GIT_HASH .
```

Запуск контейнера:

```bash
docker run --rm -p 3000:3000 dovzhuktimofii/nodeapp:$GIT_HASH
```

## Docker Compose + PostgreSQL

Для локального запуску двох сервісів:

```bash
docker compose up --build
```

Перевірка:

```bash
docker compose ps
docker compose logs app
docker compose logs db
```

Зупинка:

```bash
docker compose down
```

## GitHub Secrets

Для Docker Hub:

- `DOCKERHUB_USERNAME` — ім'я користувача Docker Hub;
- `DOCKERHUB_TOKEN` — Personal Access Token Docker Hub.

Для AWS EC2:

- `EC2_HOST` — публічна IP-адреса інстансу;
- `EC2_USER` — користувач SSH, наприклад `ubuntu`;
- `EC2_SSH_KEY_B64` — приватний `.pem` ключ у Base64.

Без цих секретів CI все одно виконує тести, build і локальну збірку Docker-образу. Публікація в Docker Hub та EC2-деплой активуються після додавання відповідних секретів.

## CI/CD

Workflow розташований у:

```text
.github/workflows/ci.yml
```

Після push у `main` GitHub Actions:

1. встановлює залежності;
2. запускає тести;
3. виконує build;
4. генерує тег на основі SHA коміту;
5. збирає Docker-образ;
6. за наявності секретів пушить образ у Docker Hub;
7. за наявності EC2 секретів підключається до сервера;
8. видаляє PM2;
9. встановлює Docker за потреби;
10. запускає Node.js і PostgreSQL через Docker Compose.
