# CI/CD Node.js + Docker + PostgreSQL + Terraform

Навчальний Node.js-проєкт для практичних занять із CI/CD, AWS EC2, Docker та Terraform.

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
- Terraform-конфігурація для створення EC2 та Security Group;
- автоматична перевірка Terraform через GitHub Actions;
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

## Terraform

Terraform-файли розташовані в каталозі:

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

Конфігурація створює:

- AWS Security Group;
- SSH-доступ на порт `22`;
- доступ до Node.js-застосунку на порт `3000`;
- EC2-інстанс;
- публічну IP-адресу для подальшого деплою.

У `terraform/terraform.tfvars` за замовчуванням використовується:

```hcl
aws_region       = "us-east-1"
ami_id           = ""
instance_type    = "t3.micro"
key_name         = "devops-key"
private_key_path = "../devops-key.pem"
ssh_cidr         = "0.0.0.0/0"
```

Якщо `ami_id` залишити порожнім, Terraform автоматично знайде актуальний офіційний Ubuntu 24.04 LTS AMI від Canonical. За потреби можна вказати конкретний AMI ID вручну.

Перед `terraform apply` у AWS має існувати EC2 Key Pair з назвою, яка відповідає `key_name`.

### Створення інфраструктури

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Підтвердіть створення введенням:

```text
yes
```

Після успішного створення Terraform виведе, зокрема:

```text
instance_ip = "x.x.x.x"
application_url = "http://x.x.x.x:3000"
```

Значення `instance_ip` потрібно додати або оновити в GitHub Secret:

```text
EC2_HOST
```

Після цього наступний push у `main` зможе виконати Docker-деплой на створений сервер, якщо також налаштовані інші необхідні секрети.

### Видалення інфраструктури

Після перевірки практичної роботи:

```bash
cd terraform
terraform destroy
```

Підтвердіть:

```text
yes
```

Це видалить створені Terraform EC2 та Security Group і допоможе уникнути зайвих витрат AWS.

## GitHub Secrets

Для Docker Hub:

- `DOCKERHUB_USERNAME` — ім'я користувача Docker Hub;
- `DOCKERHUB_TOKEN` — Personal Access Token Docker Hub.

Для AWS EC2:

- `EC2_HOST` — публічна IP-адреса інстансу з `terraform output instance_ip`;
- `EC2_USER` — користувач SSH, наприклад `ubuntu`;
- `EC2_SSH_KEY_B64` — приватний `.pem` ключ у Base64.

Без цих секретів CI все одно виконує Terraform validate, тести, build і локальну збірку Docker-образу. Публікація в Docker Hub та EC2-деплой активуються після додавання відповідних секретів.

## GitHub Actions CI/CD

Workflow розташований у:

```text
.github/workflows/ci.yml
```

Після push у `main` GitHub Actions:

1. перевіряє формат Terraform;
2. виконує `terraform init -backend=false`;
3. виконує `terraform validate`;
4. встановлює Node.js залежності;
5. запускає тести;
6. виконує build;
7. генерує Docker-тег на основі SHA коміту;
8. збирає Docker-образ;
9. за наявності секретів пушить образ у Docker Hub;
10. за наявності EC2 секретів підключається до сервера;
11. встановлює Docker за потреби;
12. запускає Node.js і PostgreSQL через Docker Compose.

## Безпека

У `.gitignore` виключені:

```text
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfstate
*.pem
node_modules/
.env
```

Приватні SSH-ключі, Terraform state та інші секретні файли не повинні потрапляти в GitHub.
