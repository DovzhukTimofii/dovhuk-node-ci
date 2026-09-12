# Ohm Lab — індивідуальний проєкт DevOps

**Автор:** Довжук Тимофій Андрійович, КН-41.

Ohm Lab обчислює силу струму `I = U / R` та потужність `P = U × I` для резистивного
кола постійного струму. Є вебформа українською, HTTP API та перевірки вхідних даних.
PostgreSQL збережено з попередніх практичних: `/ready` перевіряє реальне підключення.
Розрахунки не записуються в базу. Це власне розширення попереднього NodeApp.

## Структура

| Шлях | Призначення |
|---|---|
| `src/server.js`, `src/index.html` | API і вебінтерфейс |
| `test/server.test.js` | Перевірка формул, помилок API та недоступності БД |
| `Dockerfile`, `docker-compose.yml` | Контейнери Node.js і PostgreSQL |
| `infra/` | Terraform: EC2, Security Group, S3 backend |
| `scripts/deploy.sh` | SSH, Docker Compose, перевірка готовності |
| `../../.github/workflows/ci.yml` | Активний workflow у корені репозиторію |

## 1. Локальний запуск (PowerShell)

Потрібні Git, Docker Desktop у режимі Linux containers; Node.js 22 для тестів без Docker.
Усі наступні команди виконуються з кореня клонованого репозиторію, якщо не вказано інше.

```powershell
cd students/dovzhuk-timofii
Copy-Item .env.example .env
# Відредагуйте POSTGRES_PASSWORD у .env (латинські літери, цифри, _ або -).
docker compose up -d --build --wait
curl.exe --fail http://localhost:3000/ready
curl.exe --fail 'http://localhost:3000/api/ohm?voltage=12&resistance=100'
```

Відкрийте http://localhost:3000. Для 12 В і 100 Ом результат: 0,12 А та 1,44 Вт.

```powershell
docker compose logs --tail=50
docker compose down
npm ci
npm test
npm run build
```

`down` зберігає дані БД. `down -v` видаляє локальний volume з даними — використовуйте
тільки якщо ці дані більше не потрібні.

Окремий контейнер без PostgreSQL:

```powershell
docker build -t ohm-lab:local .
docker run --rm -p 3000:3000 ohm-lab:local
```

Без `DATABASE_URL` обчислення працюють, `/ready` повертає `database: disabled`.

## 2. Що виконує CI/CD

PR: `npm ci` → реальні тести → синтаксична перевірка → Terraform fmt/validate →
Docker Compose build і запуск → HTTP-перевірки з PostgreSQL → очищення тестових контейнерів.
PR не отримує ключів деплою й не змінює AWS.

Push у `main` / ручний запуск на `main`: ті самі перевірки → перевірка секретів →
Docker Hub push образу з повним SHA коміту → Terraform plan/apply зі спільним state у S3 →
IP із Terraform output → SSH → pull та `compose up --wait` → перевірка `/ready` на EC2.
При відсутній конфігурації job завершується помилкою, а не удає успішний деплой.

Dockerfile використовує Node 22 slim, `npm ci --omit=dev`, кеш залежностей,
непривілейованого користувача `node`, явне копіювання `src` та healthcheck.
Теги образів прив'язані до повного SHA; повторні деплої серіалізовано через concurrency.
State має S3 lockfile. Terraform plan і приватні ключі не завантажуються як artifacts.

## 3. Docker Hub — виправлення поточної помилки

Помилка старого запуску: `unauthorized: access token has insufficient scopes`.

1. У Docker Hub увійдіть у свій акаунт → Account settings → Personal access tokens.
2. Створіть токен із правами **Read & Write** (видалення образів не потрібне).
3. Створіть або перевірте **публічний** репозиторій `nodeapp` у власному namespace.
   Поточний EC2 deploy розрахований на публічний образ; приватний потребує окремої
   автентифікації Docker на сервері.
4. GitHub → Settings → Secrets and variables → Actions → Secrets:
   додайте `DOCKER_USERNAME` та `DOCKER_TOKEN`.
5. Старі `DOCKERHUB_USERNAME` і `DOCKERHUB_TOKEN` підтримуються як fallback.
   Якщо нове ім'я вже задано, воно має пріоритет — оновіть саме його.

Токени та ключі вводьте лише у Secrets, не в README або чат.

## 4. Налаштування GitHub

[Secrets та variables цього репозиторію](https://github.com/DovzhukTimofii/dovhuk-node-ci/settings/secrets/actions).

### Secrets

| Назва | Значення |
|---|---|
| `DOCKER_USERNAME` | Ваш Docker Hub username, малими літерами |
| `DOCKER_TOKEN` | Docker Hub PAT із Write |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key для Terraform |
| `AWS_SECRET_ACCESS_KEY` | Відповідний secret access key |
| `AWS_SESSION_TOKEN` | Лише для тимчасових AWS credentials; вони мають термін дії |
| `EC2_SSH_KEY_B64` | Base64 вашого існуючого приватного PEM ключа |
| `EC2_USER` | `ubuntu` для стандартного Ubuntu AMI; за замовчуванням `ubuntu` |
| `EC2_KNOWN_HOSTS` | Перевірений SSH host key сервера з alias `nodeapp`, див. нижче |
| `POSTGRES_PASSWORD` | Пароль БД: латинські літери, цифри, `_` або `-` |

`EC2_HOST` більше не потрібний: адреса береться з Terraform output.

### Repository Variables (вкладка Variables, не Secrets)

| Назва | Значення |
|---|---|
| `AWS_REGION` | Регіон наявного EC2, за замовчуванням `us-east-1` |
| `TF_STATE_BUCKET` | Ім'я вашого приватного S3 bucket для state, обов'язково |
| `EC2_KEY_NAME` | Ім'я існуючого EC2 Key Pair, за замовчуванням `devops-key` |
| `EC2_INSTANCE_TYPE` | Тип наявного сервера, за замовчуванням `t3.micro` |
| `EC2_AMI_ID` | Необов'язково: AMI для нового сервера |

Workflow використовує GitHub environment `production`. За потреби налаштуйте його
правила доступу в Settings → Environments. Не запускайте deploy до міграції state.

## 5. AWS і Terraform: одноразова підготовка

Потрібні AWS CLI із налаштованим профілем (`aws configure`), Terraform 1.10.5,
EC2 Key Pair і default VPC у вибраному регіоні. Ця конфігурація використовує default VPC.
Без нього треба відновити default VPC або адаптувати конфігурацію до власної VPC/subnet.

AWS IAM identity повинна мати права на читання EC2/AMI/VPC, створення й оновлення
EC2, Security Groups і правил, тегування ресурсів, а також на S3 backend.
Для state потрібні `s3:ListBucket` на ваш bucket, `s3:GetObject` і `s3:PutObject` на
`dovhuk-node-ci/terraform.tfstate`, а також Get/Put/DeleteObject на
`dovhuk-node-ci/terraform.tfstate.tflock`. Для створення bucket потрібні окремі права.
IAM root access keys не використовуйте. Якщо навчальний AWS акаунт обмежений,
ці права має надати його адміністратор.

У S3 console створіть bucket у тому самому регіоні, увімкніть **Block all public access**,
**Versioning** і серверне шифрування. Вкажіть його ім'я у `TF_STATE_BUCKET`.
Це одноразова підготовка backend; сам EC2 і Security Group керуються Terraform.
[S3 backend і права доступу — HashiCorp](https://developer.hashicorp.com/terraform/language/backend/s3).

### Якщо сервер вже створений Terraform

**Не запускайте apply з порожнім state для існуючого сервера.** Спочатку зробіть
локальну резервну копію попереднього `terraform.tfstate`. Не додавайте її до Git.
Адреси ресурсів `aws_instance.nodeapp` і Security Group залишено незмінними.

Після отримання нової гілки скопіюйте старий state у нову папку (з кореня репозиторію):

```powershell
Copy-Item terraform/terraform.tfstate students/dovzhuk-timofii/infra/terraform.tfstate
cd students/dovzhuk-timofii/infra
Copy-Item terraform.tfvars.example terraform.tfvars
# Відредагуйте регіон, key_name, instance_type під наявний сервер.
# ssh_cidr для ручного налаштування: ваша зовнішня IPv4-адреса з /32.
terraform init -migrate-state -backend-config="bucket=YOUR_BUCKET" -backend-config="region=us-east-1"
```

Погодьтеся перенести локальний state у S3. Замініть `YOUR_BUCKET` і регіон своїми.
Перевірте `terraform state list`, потім `terraform plan`: не повинно бути другого
EC2 або заміни наявного. Перенесіть ті самі параметри з tfvars у GitHub Variables.
Якщо вже був remote backend, використовуйте його фактичний bucket/key; не копіюйте
застарілий локальний state поверх актуального remote state.

Якщо EC2 існує, але state втрачено, зупиніться перед apply: потрібен `terraform import`
для EC2, Security Group та її правил з їхніми справжніми AWS IDs. Один import EC2
не відновлює всі ресурси. Після імпорту перевірте plan. IDs не можна вгадувати.

### Якщо сервер ще не створений

```powershell
cd students/dovzhuk-timofii/infra
Copy-Item terraform.tfvars.example terraform.tfvars
# Налаштуйте aws_region, key_name, instance_type і ssh_cidr = "YOUR_IP/32".
terraform init -backend-config="bucket=YOUR_BUCKET" -backend-config="region=us-east-1"
terraform plan
terraform apply
terraform output
```

Перший apply вручну потрібен для отримання і перевірки SSH host key до автоматичного
деплою. Наступні push автоматично виконують plan/apply і беруть IP зі спільного state.
`prevent_destroy` захищає EC2 від випадкової заміни; зміна останнього Ubuntu AMI
не пересоздає наявний сервер. Для свідомої заміни потрібна окрема зміна конфігурації.

### SSH credentials

Base64 у PowerShell — скопіювати прямо в буфер обміну:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\devops-key.pem')) | Set-Clipboard
```

Вставте в `EC2_SSH_KEY_B64`. Приватний ключ має відповідати `EC2_KEY_NAME`.

Для `EC2_KNOWN_HOSTS` отримайте public host key **через довірений доступ до EC2**,
наприклад AWS Console → EC2 Instance Connect (якщо налаштовано). На сервері:

```bash
sudo awk '{print "nodeapp " $1 " " $2}' /etc/ssh/ssh_host_ed25519_key.pub
```

Збережіть отриманий рядок `nodeapp ssh-ed25519 AAAA...` у `EC2_KNOWN_HOSTS`.
Якщо берете ключ через `ssh-keyscan`, спочатку звірте fingerprint із сервером через
довірений канал. Не додавайте `StrictHostKeyChecking=no`.
Після заміни сервера host key потрібно перевірити й оновити.

Під час CI Terraform тимчасово встановлює SSH ingress тільки на IP поточного runner.
Після завершення runner цей /32 залишається до наступного apply; порт не відкривається
на весь інтернет. Для ручного SSH задайте свою адресу через Terraform apply.

### Збереження старої PostgreSQL

Деплой використовує попередню папку `~/nodeapp`, compose project `nodeapp` і volume
`nodeapp_postgres_data`. Якщо БД уже ініціалізована, задайте **її поточний пароль**:
нова змінна `POSTGRES_PASSWORD` сама не змінює пароль наявного користувача PostgreSQL.
Якщо старий пароль був `postgres`, для першого перенесення він має збігатися; зміну
пароля робіть окремо через SQL і оновлення Secrets. Не видаляйте volume для обходу помилки.
Старі сторонні PM2 процеси автоматично не видаляються. Якщо порт 3000 зайнятий,
визначте процес через `sudo ss -ltnp` та зупиніть лише старий навчальний застосунок.

## 6. Змінні застосунку й API

| Змінна | Призначення |
|---|---|
| `PORT` | HTTP порт, 3000 за замовчуванням |
| `DATABASE_URL` | Увімкнення підключення PostgreSQL; Compose задає host/db |
| `PGUSER`, `PGPASSWORD` | Credentials PostgreSQL, надходять з Compose |
| `POSTGRES_PASSWORD` | Compose пароль для БД і застосунку |
| `DOCKER_USERNAME`, `IMAGE_TAG` | Образ для Compose; local defaults для локальної збірки |

| GET endpoint | Результат |
|---|---|
| `/` | Вебформа |
| `/api/ohm?voltage=12&resistance=100` | JSON: voltage, resistance, current, power |
| `/health` | 200, HTTP процес працює |
| `/ready` | 200 з доступною БД або без налаштованої БД; 503 якщо БД недоступна |

Некоректні числа, нульовий/від'ємний опір, відсутні значення → 400.
Невідомий шлях → 404, метод не GET → 405.

## 7. Перевірка і здача

1. Отримайте зміни PR локально, запустіть Docker Compose і перевірте форму.
   Якщо автоматичний запуск PR не з’явився, з кореня репозиторію виконайте:

   ```powershell
   git fetch origin
   git switch --track origin/final-devops-project
   git commit --allow-empty -m "Run final project verification"
   git push origin final-devops-project
   ```

   Якщо локальна гілка вже існує, використовуйте `git switch final-devops-project`.
   Push у цю гілку запускає лише `verify`, без AWS деплою.
2. Підготуйте AWS, спільний state, Docker Hub та Secrets за розділами вище.
3. Злийте PR у main або запустіть workflow вручну на main після налаштування.
4. Actions повинні показати успіх **обох** jobs: `verify` і `deploy`.
5. У Docker Hub перевірте образ `USERNAME/nodeapp:FULL_COMMIT_SHA`.
6. У summary запуску відкрийте URL EC2; перевірте форму та `/ready`.
7. Передайте викладачу посилання на репозиторій, успішний запуск Actions і URL.
   Якщо потрібні скриншоти, зробіть їх із реальних Docker/Actions/EC2, а не з конфігурації.

Структура відповідає шаблону, але цей репозиторій зберігає попередню історію, а не
створений заново через Use this template. Якщо викладач вимагає саме template-origin,
створіть новий репозиторій через https://github.com/Max-K44/devops-template і перенесіть
`students/`, кореневі `.github/`, `.gitignore` та `README.md`. Secrets не переносяться.
Вимкніть deploy у старому репозиторії, перш ніж вмикати в новому: concurrency не спільна
між репозиторіями. Для того самого EC2 використовуйте той самий S3 state.

## 8. Завершення роботи

AWS EC2, диски, публічна IPv4 і S3 можуть тарифікуватися. Після перевірки й коли сервер
більше не потрібний, вимкніть workflow, щоб наступний push не створив ресурси знову.
Зробіть потрібні резервні копії. Для навмисного видалення EC2 приберіть
`prevent_destroy = true` з локальної Terraform-конфігурації, потім:

```powershell
cd students/dovzhuk-timofii/infra
terraform init -backend-config="bucket=YOUR_BUCKET" -backend-config="region=us-east-1"
terraform plan -destroy
terraform destroy
```

Це видаляє EC2 та дані його диска. Bucket backend і старі ресурси поза цим state
не видаляються цими командами. Перевірте їх окремо в AWS.

## Межі перевірки

Автоматична публікація і реальний EC2 deploy потребують ваших зовнішніх облікових даних.
Успішні unit-тести самі по собі не доводять успішний Docker/EC2 deploy.
