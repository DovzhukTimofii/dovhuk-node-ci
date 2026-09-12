# Ohm Lab

**Довжук Тимофій Андрійович · КН-41**

Ohm Lab обчислює силу струму `I = U / R` та потужність `P = U × I` для резистивного
кола постійного струму. Застосунок містить вебформу українською мовою, HTTP API
та перевірки вхідних даних. PostgreSQL використовується для перевірки готовності
через `/ready`; результати розрахунків не зберігаються в базі.

## Структура

| Шлях | Призначення |
|---|---|
| `src/server.js` | HTTP API |
| `src/index.html` | Вебінтерфейс |
| `test/server.test.js` | Тести формул, API та готовності БД |
| `Dockerfile`, `docker-compose.yml` | Контейнери Node.js і PostgreSQL |
| `infra/` | Terraform: EC2, Security Group, S3 backend |
| `scripts/deploy.sh` | SSH-деплой і перевірка готовності |
| `../../.github/workflows/ci.yml` | Workflow GitHub Actions |

## Локальний запуск

Залежності: Git, Docker із Compose v2; Node.js 22 для запуску тестів поза контейнером.
Команди PowerShell з кореня репозиторію:

```powershell
cd students/dovzhuk-timofii
Copy-Item .env.example .env
docker compose up -d --build --wait
curl.exe --fail http://localhost:3000/ready
curl.exe --fail 'http://localhost:3000/api/ohm?voltage=12&resistance=100'
```

Файл `.env` містить `POSTGRES_PASSWORD`. Допустимі символи пароля для скрипта
деплою: латинські літери, цифри, підкреслення та дефіс.

Вебінтерфейс: http://localhost:3000.
Приклад: 12 В і 100 Ом → 0,12 А та 1,44 Вт.

```powershell
docker compose logs --tail=50
docker compose down
npm ci
npm test
npm run build
```

`docker compose down` зберігає дані БД. Варіант `down -v` видаляє volume з даними.

Окремий контейнер без PostgreSQL:

```powershell
docker build -t ohm-lab:local .
docker run --rm -p 3000:3000 ohm-lab:local
```

Без `DATABASE_URL` калькулятор працює автономно; `/ready` повертає `database: disabled`.

## CI/CD

Job `verify` виконує:

1. Встановлення залежностей через `npm ci`.
2. Unit- та HTTP-тести, перевірку синтаксису.
3. Terraform fmt, init без backend та validate.
4. Збірку й запуск Docker Compose із PostgreSQL.
5. HTTP-перевірки готовності й розрахунку.
6. Видалення тестових контейнерів та volume.

Job `deploy` виконується після `verify` на гілці `main`, поза pull request,
лише якщо repository variable `ENABLE_DEPLOY` дорівнює `true`.
Без цієї змінної деплой пропускається. Коли деплой увімкнений, відсутні обов'язкові
секрети спричиняють помилку конфігурації.

Послідовність деплою: Docker Hub push із повним SHA коміту → Terraform plan/apply
зі state у S3 → IP із Terraform output → SSH → Docker Compose pull/up →
перевірка `/ready` на сервері.

Dockerfile використовує Node 22 slim, `npm ci --omit=dev`, кешування залежностей,
користувача `node` та healthcheck. Запуски серіалізуються через concurrency;
S3 backend використовує lockfile. State, плани та приватні ключі не публікуються
як artifacts. Успішний `verify` не означає виконаний `deploy`.

## Налаштування GitHub

Секрети: Settings → Secrets and variables → Actions → Secrets.

| Secret | Призначення |
|---|---|
| `DOCKER_USERNAME` | Docker Hub username малими літерами |
| `DOCKER_TOKEN` | Docker Hub PAT із правами Read & Write |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret access key |
| `AWS_SESSION_TOKEN` | Для тимчасових AWS credentials |
| `EC2_SSH_KEY_B64` | Приватний PEM ключ у Base64 |
| `EC2_USER` | SSH-користувач; за замовчуванням `ubuntu` |
| `EC2_KNOWN_HOSTS` | Перевірений SSH host key із alias `nodeapp` |
| `POSTGRES_PASSWORD` | Пароль PostgreSQL |

`DOCKERHUB_USERNAME` і `DOCKERHUB_TOKEN` підтримуються як fallback.
`DOCKER_USERNAME` та `DOCKER_TOKEN` мають пріоритет.
Адреса EC2 береться зі state через Terraform output; secret `EC2_HOST` не потрібний.

Repository Variables:

| Variable | Призначення |
|---|---|
| `ENABLE_DEPLOY` | `true` вмикає деплой; інакше тільки CI |
| `AWS_REGION` | Регіон AWS; default `us-east-1` |
| `TF_STATE_BUCKET` | Приватний S3 bucket для state |
| `EC2_KEY_NAME` | Існуючий EC2 Key Pair; default `devops-key` |
| `EC2_INSTANCE_TYPE` | Тип EC2; default `t3.micro` |
| `EC2_AMI_ID` | Необов'язковий AMI для нового сервера |

Деплой використовує GitHub environment `production`.
`ENABLE_DEPLOY=true` встановлюється після підготовки backend, state та SSH credentials.

## Docker Hub

Потрібний публічний репозиторій `nodeapp` у namespace, заданому
`DOCKER_USERNAME`. PAT створюється в Account settings → Personal access tokens
із правами Read & Write. Поточний скрипт EC2 завантажує публічний образ;
для приватного репозиторію необхідна додаткова автентифікація на сервері.

Помилка `unauthorized: access token has insufficient scopes` означає недостатні
права токена. Перевіряються право Write, namespace та актуальність GitHub Secret.

## AWS та Terraform

Залежності: Terraform 1.10.5, AWS CLI із налаштованими credentials,
EC2 Key Pair і default VPC у вибраному регіоні. Для іншої мережі необхідна
адаптація Terraform-конфігурації до відповідної VPC/subnet.

IAM identity потребує прав на читання EC2/AMI/VPC, створення й оновлення
EC2, Security Groups та правил, тегування ресурсів і доступ до S3 backend.
Root access keys не використовуються.

S3 bucket створюється одноразово в регіоні backend із Block all public access,
Versioning і серверним шифруванням. Права backend:

- `s3:ListBucket` на bucket;
- `s3:GetObject`, `s3:PutObject` на `dovhuk-node-ci/terraform.tfstate`;
- Get/Put/DeleteObject на `dovhuk-node-ci/terraform.tfstate.tflock`.

[Документація S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3).

### Нова інфраструктура

```powershell
cd students/dovzhuk-timofii/infra
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=BUCKET_NAME" -backend-config="region=us-east-1"
terraform plan
terraform apply
terraform output
```

`BUCKET_NAME` і регіон — параметри backend.
У `terraform.tfvars` задаються `aws_region`, `key_name`, `instance_type`
і `ssh_cidr` із зовнішньою IPv4-адресою адміністратора у форматі `IP/32`.
Приклад за замовчуванням не відкриває зовнішній SSH-доступ.

Початковий apply дозволяє отримати та перевірити SSH host key до першого
автоматичного деплою. Наступні запуски deploy виконують plan/apply зі спільним state.
`prevent_destroy` захищає EC2 від випадкової заміни; оновлення останнього AMI
не пересоздає наявний сервер.

### Міграція наявного state

Для інфраструктури, створеної попередньою конфігурацією, зберігаються адреси
`aws_instance.nodeapp`, Security Group та її правил.
Перед міграцією необхідна локальна резервна копія state поза Git.

Приклад перенесення локального state зі старої папки `terraform/`:

```powershell
Copy-Item terraform/terraform.tfstate students/dovzhuk-timofii/infra/terraform.tfstate
cd students/dovzhuk-timofii/infra
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init -migrate-state -backend-config="bucket=BUCKET_NAME" -backend-config="region=us-east-1"
terraform state list
terraform plan
```

Параметри tfvars мають відповідати існуючим ресурсам і GitHub Variables.
Plan не повинен створювати другий сервер або замінювати наявний.
Для вже налаштованого remote backend використовується його актуальний state,
а не застаріла локальна копія.

Якщо ресурси існують, а state втрачено, до apply потрібний `terraform import`
для EC2, Security Group та всіх керованих правил за фактичними AWS IDs.
Імпорт лише EC2 не відновлює решту ресурсів.

### SSH

Перетворення приватного PEM ключа в Base64 у PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\devops-key.pem')) | Set-Clipboard
```

Результат зберігається в `EC2_SSH_KEY_B64`; ключ має відповідати `EC2_KEY_NAME`.

Публічний host key отримується через довірений канал доступу до EC2, наприклад
налаштований EC2 Instance Connect. Команда на сервері:

```bash
sudo awk '{print "nodeapp " $1 " " $2}' /etc/ssh/ssh_host_ed25519_key.pub
```

Рядок `nodeapp ssh-ed25519 AAAA...` зберігається в `EC2_KNOWN_HOSTS`.
Для результату `ssh-keyscan` необхідна звірка fingerprint через довірений канал.
Перевірка host key увімкнена; після заміни сервера ключ оновлюється.

Під час deploy Terraform встановлює SSH ingress на IPv4 поточного runner з маскою /32.
Правило залишається до наступного apply. Для ручного доступу конфігурація
`ssh_cidr` змінюється на адресу адміністратора.

### PostgreSQL та існуючі процеси

Деплой використовує `~/nodeapp`, Compose project `nodeapp` і volume
`nodeapp_postgres_data`. Для вже ініціалізованої БД secret `POSTGRES_PASSWORD`
має відповідати поточному паролю. Зміна environment variable сама не змінює пароль
існуючого PostgreSQL-користувача; ротація виконується через SQL та оновлення Secrets.

Сторонні PM2 процеси не видаляються. Конфлікт порту 3000 діагностується через
`sudo ss -ltnp`; зупиняється лише процес, який має бути замінений.

## Змінні застосунку

| Змінна | Призначення |
|---|---|
| `PORT` | HTTP порт, default 3000 |
| `DATABASE_URL` | Підключення PostgreSQL; без неї БД вимкнена |
| `PGUSER`, `PGPASSWORD` | Credentials PostgreSQL |
| `POSTGRES_PASSWORD` | Пароль БД у Compose |
| `DOCKER_USERNAME`, `IMAGE_TAG` | Образ для Compose |

## API

| GET endpoint | Результат |
|---|---|
| `/` | Вебформа |
| `/api/ohm?voltage=12&resistance=100` | JSON: voltage, resistance, current, power |
| `/health` | HTTP 200, процес працює |
| `/ready` | 200: БД доступна або вимкнена; 503: налаштована БД недоступна |

Некоректні числа, відсутні значення, нульовий або від'ємний опір → HTTP 400.
Невідомий шлях → 404. Метод, відмінний від GET → 405.

## Перевірка розгортання

Після ввімкнення деплою успішний запуск містить виконані jobs `verify` і `deploy`.
У summary доступні URL застосунку та образ `USERNAME/nodeapp:FULL_COMMIT_SHA`.
Перевірка вебформи і `/ready` підтверджує доступність сервера.
Пропущений job `deploy` не підтверджує публікацію образу або запуск EC2.

## Видалення інфраструктури

Перед видаленням `ENABLE_DEPLOY` вимикається, потрібні дані резервуються.
Для навмисного видалення EC2 з локальної конфігурації прибирається
`prevent_destroy = true`.

```powershell
cd students/dovzhuk-timofii/infra
terraform init -backend-config="bucket=BUCKET_NAME" -backend-config="region=us-east-1"
terraform plan -destroy
terraform destroy
```

Видаляються EC2 і дані його диска. S3 bucket та ресурси поза поточним state
керуються окремо. EC2, диски, публічна IPv4 і S3 можуть тарифікуватися.
