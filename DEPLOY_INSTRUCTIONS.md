# Полная инструкция по развертыванию тестового приложения

## Обзор процесса

Мы развернем простое веб-приложение "Hello World" на nginx в Yandex Cloud:

1. ✅ **Создали HTML страницу** - красивую тестовую страницу с анимацией
2. ✅ **Создали Dockerfile** - для сборки nginx контейнера
3. ✅ **Создали nginx.conf** - конфигурацию веб-сервера
4. 🔧 **Развернем Container Registry** - через Terraform
5. 🔧 **Соберем и загрузим образ** - мультиплатформенная сборка
6. 🔧 **Протестируем автоматическое развертывание** - на ВМ в облаке

## Структура проекта

```
test-app/
├── index.html      # HTML страница Hello World
├── nginx.conf      # Конфигурация nginx
└── Dockerfile      # Инструкции для сборки образа
```

---

# ИНСТРУКЦИЯ ПО ЗАПУСКУ

## Предварительные требования

**На вашем MacBook должно быть установлено:**

- [Colima](https://github.com/abiosoft/colima) ✅ (у вас уже есть)
- [Docker CLI](https://docs.docker.com/engine/install/)
- [Yandex Cloud CLI](https://cloud.yandex.ru/docs/cli/quickstart)
- [Terraform](https://www.terraform.io/downloads)

**Проверим что все работает:**

```bash
# Проверка Colima
colima status

# Проверка Docker
docker --version

# Проверка yc CLI
yc --version

# Проверка Terraform
terraform --version
```

---

## ШАГ 1: Запуск Colima (если не запущена)

```bash
# Запуск Colima с поддержкой мультиплатформенной сборки
colima start --cpu 4 --memory 8 --disk 60

# Проверка статуса
colima status
docker info
```

---

## ШАГ 2: Настройка Yandex Cloud

```bash
# Инициализация yc CLI (если еще не сделано)
yc init

# Создание профиля для Terraform
yc config profile create terraform-profile

# Установка параметров
yc config set cloud-id <ваш-cloud-id>
yc config set folder-id <ваш-folder-id>

# Создание сервисного аккаунта для Terraform
yc iam service-account create --name terraform-sa

# Получение ID сервисного аккаунта
export SA_ID=$(yc iam service-account get terraform-sa --format json | jq -r .id)

# Назначение роли editor
yc resource-manager folder add-access-binding <ваш-folder-id> \
  --role editor \
  --subject serviceAccount:$SA_ID

# Создание ключа для сервисного аккаунта
yc iam key create \
  --service-account-id $SA_ID \
  --output terraform-key.json
```

---

## ШАГ 3: Развертывание Container Registry через Terraform

```bash
# Переход в директорию Terraform
cd terraform/infrastructure

# Создание конфигурационного файла
cat > terraform.tfvars << EOF
folder_id = "$(yc config get folder-id)"
enable_container_registry = true
container_registry_name = "test-app-registry"
enable_container_deployment = true
app_port = 80
EOF

# Инициализация Terraform
terraform init

# Планирование изменений
terraform plan

# Применение конфигурации
terraform apply
```

**Сохраните выходные данные:**

```bash
# Получение ID и URL Registry
export REGISTRY_ID=$(terraform output -raw container_registry_id)
export REGISTRY_URL=$(terraform output -raw container_registry_url)

echo "Registry ID: $REGISTRY_ID"
echo "Registry URL: $REGISTRY_URL"
```

---

## ШАГ 4: Локальная сборка и тестирование

```bash
# Возврат в корневую директорию
cd ../../

# Локальная сборка образа для тестирования
docker build -t test-hello-world:local test-app/

# Локальный запуск для проверки
docker run -d --name test-local -p 8080:80 test-hello-world:local

# Тестирование в браузере
open http://localhost:8080

# Остановка локального контейнера
docker stop test-local
docker rm test-local
```

---

## ШАГ 5: Сборка мультиплатформенного образа

```bash
# Создание buildx builder для мультиплатформенной сборки
docker buildx create --name multiplatform-builder --use

# Аутентификация в Yandex Container Registry
yc iam create-token | docker login --username iam --password-stdin cr.yandex

# Мультиплатформенная сборка и загрузка
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag $REGISTRY_URL/hello-world:v1.0.0 \
  --tag $REGISTRY_URL/hello-world:latest \
  --push \
  test-app/

# Проверка загруженного образа
yc container image list --registry-id $REGISTRY_ID
```

---

## ШАГ 6: Настройка автоматического развертывания

```bash
# Обновление конфигурации Terraform для развертывания контейнера
cd terraform/infrastructure

# Получение IAM токена для развертывания
export IAM_TOKEN=$(yc iam create-token)

# Обновление terraform.tfvars
cat >> terraform.tfvars << EOF
container_image = "$REGISTRY_URL/hello-world:latest"
ycr_iam_token = "$IAM_TOKEN"
EOF

# Применение обновленной конфигурации
terraform apply
```

---

## ШАГ 7: Проверка развертывания

```bash
# Получение IP адресов ВМ
terraform output microservices_ips

# Получение внешнего IP frontend ВМ
export FRONTEND_IP=$(terraform output -json microservices_ips | jq -r .frontend.external_ip)

echo "Приложение должно быть доступно по адресу: http://$FRONTEND_IP"

# Ожидание запуска (cloud-init может занять 2-3 минуты)
echo "Ждем запуска приложения..."
for i in {1..30}; do
  if curl -s http://$FRONTEND_IP > /dev/null; then
    echo "✅ Приложение запущено!"
    break
  fi
  echo "Попытка $i/30..."
  sleep 10
done

# Открытие в браузере
open http://$FRONTEND_IP
```

---

## ШАГ 8: Мониторинг и отладка

```bash
# SSH подключение к ВМ для проверки
terraform output -raw ssh_private_key > ssh_key.pem
chmod 600 ssh_key.pem

ssh -i ssh_key.pem ubuntu@$FRONTEND_IP

# На ВМ выполните:
sudo docker ps                              # Статус контейнеров
sudo docker logs myapp                      # Логи приложения
sudo tail -f /var/log/container-deployment.log  # Логи развертывания
curl localhost:80                           # Локальная проверка
```

---

## Обновление приложения

```bash
# 1. Внесите изменения в test-app/index.html

# 2. Пересоберите образ с новой версией
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag $REGISTRY_URL/hello-world:v1.1.0 \
  --tag $REGISTRY_URL/hello-world:latest \
  --push \
  test-app/

# 3. Перезапустите контейнер на ВМ вручную или через Terraform
ssh -i ssh_key.pem ubuntu@$FRONTEND_IP
sudo docker pull $REGISTRY_URL/hello-world:latest
sudo docker stop myapp
sudo docker rm myapp
sudo docker run -d --name myapp -p 80:80 $REGISTRY_URL/hello-world:latest
```

---

## Очистка ресурсов

```bash
# Удаление всех созданных ресурсов
cd terraform/infrastructure
terraform destroy

# Удаление локальных образов
docker rmi test-hello-world:local
docker rmi $REGISTRY_URL/hello-world:latest
docker rmi $REGISTRY_URL/hello-world:v1.0.0

# Остановка Colima (если нужно)
colima stop
```

---

## Устранение неполадок

### Проблема: Colima не запускается

```bash
colima delete
colima start --cpu 4 --memory 8 --disk 60
```

### Проблема: Ошибка аутентификации в Registry

```bash
# Проверка токена
yc iam create-token

# Повторная аутентификация
yc iam create-token | docker login --username iam --password-stdin cr.yandex
```

### Проблема: Контейнер не запускается на ВМ

```bash
# Проверка на ВМ
ssh -i ssh_key.pem ubuntu@$FRONTEND_IP
sudo cat /var/log/cloud-init-output.log | tail -50
sudo docker logs myapp
```

### Проблема: Приложение недоступно

```bash
# Проверка портов на ВМ
ssh -i ssh_key.pem ubuntu@$FRONTEND_IP
sudo netstat -tlnp | grep :80
sudo ufw status
```

---

**🎉 После выполнения всех шагов у вас будет:**

- ✅ Container Registry в Yandex Cloud
- ✅ Мультиплатформенный Docker образ
- ✅ Автоматическое развертывание на ВМ
- ✅ Веб-приложение доступное по внешнему IP
