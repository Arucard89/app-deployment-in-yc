# Руководство по развертыванию контейнеров через Yandex Lockbox

## Обзор

Данное решение позволяет безопасно развертывать Docker-контейнеры из Yandex Container Registry на виртуальных машинах, используя Yandex Lockbox для хранения учетных данных.

## Архитектура безопасности

1. **IAM токен** хранится в зашифрованном виде в Yandex Lockbox
2. **Виртуальные машины** получают доступ к Lockbox через сервисный аккаунт
3. **Токены** извлекаются только во время развертывания и сразу удаляются из памяти
4. **Логирование** всех операций для аудита и отладки

## Предварительные требования

### 1. Подготовка Container Registry

```bash
# Создание Container Registry
yc container registry create --name my-app-registry

# Получение ID registry
REGISTRY_ID=$(yc container registry get my-app-registry --format json | jq -r .id)
echo "Registry ID: $REGISTRY_ID"
```

### 2. Создание и загрузка образа

```bash
# Создание простого тестового приложения
cat > app.py << EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return '<h1>Hello from Yandex Cloud!</h1><p>Container deployed via Lockbox</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

# Создание Dockerfile
cat > Dockerfile << EOF
FROM python:3.9-slim
WORKDIR /app
RUN pip install flask
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
EOF

# Сборка и загрузка образа
docker build -t cr.yandex/$REGISTRY_ID/my-app:latest .
docker push cr.yandex/$REGISTRY_ID/my-app:latest
```

### 3. Получение IAM токена

```bash
# Получение IAM токена (действителен 12 часов)
IAM_TOKEN=$(yc iam create-token)
echo "IAM Token: $IAM_TOKEN"
```

## Развертывание инфраструктуры

### 1. Создание terraform.tfvars

```hcl
# terraform.tfvars
folder_id = "b1g..."  # Ваш folder ID

# Настройки Container Registry
enable_container_deployment = true
container_registry_id = "crp..."  # ID вашего registry
container_image = "cr.yandex/crp.../my-app:latest"
app_port = 8080

# IAM токен (будет сохранен в Lockbox)
ycr_iam_token = "t1.9euelZr..."  # Ваш IAM токен
```

### 2. Выполнение развертывания

```bash
cd terraform/infrastructure

# Инициализация Terraform
terraform init

# Планирование изменений
terraform plan

# Применение конфигурации
terraform apply
```

### 3. Проверка результатов

```bash
# Получение IP адресов ВМ
terraform output microservices_ips

# Получение ID секрета Lockbox
terraform output lockbox_secret_id

# Статус развертывания контейнеров
terraform output container_deployment_status
```

## Проверка работы контейнера

### Через SSH

```bash
# Получение SSH ключа
terraform output -raw ssh_private_key > ssh_key.pem
chmod 600 ssh_key.pem

# Подключение к ВМ frontend (имеет внешний IP)
FRONTEND_IP=$(terraform output -json microservices_ips | jq -r .frontend.external_ip)
ssh -i ssh_key.pem ubuntu@$FRONTEND_IP

# На ВМ проверка статуса контейнера
sudo docker ps
sudo docker logs myapp
curl localhost:80
```

### Через браузер

```bash
# Получение внешнего IP frontend ВМ
FRONTEND_IP=$(terraform output -json microservices_ips | jq -r .frontend.external_ip)
echo "Откройте в браузере: http://$FRONTEND_IP"
```

## Логирование и мониторинг

### Просмотр логов развертывания

```bash
# На ВМ
sudo tail -f /var/log/container-deployment.log
```

### Просмотр логов контейнера

```bash
# Логи приложения
sudo docker logs myapp

# Логи в реальном времени
sudo docker logs -f myapp
```

### Проверка статуса сервисов

```bash
# Статус Docker
sudo systemctl status docker

# Запущенные контейнеры
sudo docker ps

# Статистика ресурсов
sudo docker stats myapp
```

## Обновление приложения

### 1. Обновление образа

```bash
# Сборка новой версии
docker build -t cr.yandex/$REGISTRY_ID/my-app:v2.0 .
docker push cr.yandex/$REGISTRY_ID/my-app:v2.0
```

### 2. Обновление конфигурации

```hcl
# В terraform.tfvars
container_image = "cr.yandex/crp.../my-app:v2.0"
```

### 3. Повторное развертывание

```bash
terraform apply
```

## Управление секретами

### Просмотр секрета в Lockbox

```bash
# Получение информации о секрете
LOCKBOX_ID=$(terraform output -raw lockbox_secret_id)
yc lockbox secret get $LOCKBOX_ID

# Просмотр версий секрета
yc lockbox secret list-versions $LOCKBOX_ID
```

### Обновление IAM токена

```bash
# Получение нового токена
NEW_IAM_TOKEN=$(yc iam create-token)

# Обновление в terraform.tfvars
# ycr_iam_token = "новый_токен"

# Применение изменений
terraform apply
```

### Ротация токена (автоматизация)

```bash
#!/bin/bash
# update_token.sh
set -e

echo "Обновление IAM токена..."
NEW_TOKEN=$(yc iam create-token)

# Обновление tfvars
sed -i "s/ycr_iam_token = \".*\"/ycr_iam_token = \"$NEW_TOKEN\"/" terraform.tfvars

# Применение изменений
terraform apply -auto-approve

echo "Токен обновлен успешно"
```

## Безопасность

### Рекомендации

1. **Регулярно обновляйте IAM токены** (каждые 12 часов)
2. **Используйте минимальные права доступа** для сервисных аккаунтов
3. **Мониторьте доступ к Lockbox** через аудит-логи
4. **Не храните токены в git-репозитории**
5. **Используйте отдельные секреты** для разных сред (dev/staging/prod)

### Настройка ролей

```bash
# Создание сервисного аккаунта только для чтения registry
yc iam service-account create --name registry-reader

# Назначение минимальных прав
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role container-registry.images.puller \
  --subject serviceAccount:$SA_ID
```

## Устранение неполадок

### Контейнер не запускается

```bash
# Проверка логов cloud-init
sudo cat /var/log/cloud-init-output.log

# Проверка логов развертывания
sudo cat /var/log/container-deployment.log

# Проверка Docker
sudo docker ps -a
sudo docker logs myapp
```

### Ошибки аутентификации

```bash
# Проверка прав сервисного аккаунта ВМ
curl -H "Metadata-Flavor: Google" \
  http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token

# Проверка доступа к Lockbox
LOCKBOX_ID="ваш_lockbox_id"
VM_TOKEN="токен_из_предыдущей_команды"
curl -H "Authorization: Bearer $VM_TOKEN" \
  "https://payload.lockbox.api.cloud.yandex.net/lockbox/v1/secrets/$LOCKBOX_ID/payload"
```

### Сетевые проблемы

```bash
# Проверка подключения к YCR
telnet cr.yandex 443

# Проверка DNS
nslookup cr.yandex

# Проверка маршрутизации
ip route
```

## Масштабирование

### Развертывание на несколько ВМ

Текущая конфигурация развертывает контейнер только на ВМ с `nat_enabled = true`. Для развертывания на всех ВМ:

```hcl
# В cloud-init.yaml измените условие
%{ if enable_container_deployment && container_image != "" && lockbox_secret_id != "" ~}
```

### Балансировка нагрузки

```bash
# Создание Application Load Balancer
yc application-load-balancer load-balancer create \
  --name app-balancer \
  --network-name app-network
```

## Автоматизация CI/CD

### GitHub Actions пример

```yaml
# .github/workflows/deploy.yml
name: Deploy to Yandex Cloud
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Build and Push to YCR
        env:
          YC_TOKEN: ${{ secrets.YC_TOKEN }}
        run: |
          echo "$YC_TOKEN" | docker login --username iam --password-stdin cr.yandex
          docker build -t cr.yandex/$REGISTRY_ID/my-app:$GITHUB_SHA .
          docker push cr.yandex/$REGISTRY_ID/my-app:$GITHUB_SHA

      - name: Update Terraform
        run: |
          echo "container_image = \"cr.yandex/$REGISTRY_ID/my-app:$GITHUB_SHA\"" >> terraform.tfvars
          terraform apply -auto-approve
```

Это полное руководство по использованию Lockbox для безопасного развертывания контейнеров в Yandex Cloud.
