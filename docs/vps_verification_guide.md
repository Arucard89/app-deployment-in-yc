# Проверка корректного создания VPS и загрузки Docker-образов

Документ описывает, как подтвердить, что Terraform развернул микросервисные VPS без ошибок и что каждая машина подтянула требуемые контейнеры из Yandex Container Registry (YCR). В конце приведены минимальные примеры Dockerfile для публикации в реестр.

---

## 1. Проверяем создание инфраструктуры

1. **Terraform output** – после `terraform apply` убедитесь, что команда завершилась без ошибок и в выводе присутствует:

   - `microservices_ips` – карты с internal/external IP.
   - либо создаётся файл `<timestamp>_deployment_vars.env` в `terraform/infrastructure/`.

2. **YC CLI**

   ```bash
   yc compute instance list --folder-id $YC_FOLDER_ID
   ```

   Должны появиться инстансы `frontend`, `api`, `main`, `billing-mail` со статусом `RUNNING`.

3. **Проверить статус конкретной ВМ**
   ```bash
   yc compute instance get frontend --format=json | jq .status
   # => "RUNNING"
   ```

---

## 2. Проверяем cloud-init и Docker на VPS

1. **SSH-подключение** (ключ вывел Terraform):

   ```bash
   ssh -i microservices_ssh_key.pem ubuntu@<frontend_internal_ip>
   ```

2. **Логи cloud-init**

   ```bash
   sudo journalctl -u cloud-final -n 50 --no-pager
   ```

3. **Контейнеры должны быть запущены**

   ```bash
   docker ps
   # CONTAINER ID  IMAGE                               NAME           ...
   # a1b2c3d4e5f6  cr.yandex/<reg>/frontend:latest     frontend-0     ...
   ```

4. **Разбор проблем**, если контейнеров нет:
   - Логи Docker: `sudo journalctl -u docker -n 100`
   - Вывод cloud-init: `/var/log/cloud-init-output.log`

---

## 3. Тестируем доступность приложения

1. Внутри ВМ:
   ```bash
   curl http://localhost/healthz   # или другой endpoint
   ```
2. Если для сервиса разрешён NAT, проверяем по `external_ip` снаружи.

---

## 4. Минимальные Dockerfile для загрузки в YCR

### 4.1 React / Vite фронтенд

```dockerfile
# ----- build stage -----
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build  # создаёт dist/

# ----- runtime stage ----
FROM nginx:1.25-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
HEALTHCHECK CMD wget -qO- http://localhost || exit 1
```

### 4.2 FastAPI Python API

```dockerfile
FROM python:3.12-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN pip install --no-cache-dir poetry \
 && poetry config virtualenvs.create false \
 && poetry install --no-dev --no-interaction --no-ansi
COPY . .
EXPOSE 8080
CMD ["uvicorn", "myapp.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Публикация в YCR

```bash
REG="cr.yandex/$YC_CR_ID"
# пример для фронтенда
docker build -t $REG/frontend:latest .
docker push $REG/frontend:latest
```

Повторите для остальных сервисов; теги должны совпадать с теми, что указаны в `terraform/infrastructure/variables.tf` (поле `images`).

---

## 5. Типовая последовательность деплоя

```bash
# 1. Собрать и запушить образы
for svc in frontend api main billing mail; do
  docker build -t $REG/$svc:latest ./services/$svc
  docker push $REG/$svc:latest
done

# 2. Применить Terraform
terraform apply -var="container_registry_id=cr.yandex/$YC_CR_ID"
```

После применения каждая VPS:

1. Логинится в YCR (SA с ролью `container-registry.images.puller`).
2. Чистит старые контейнеры.
3. Тянет новые образы.
4. Запускает их под именами `<microservice>-0`, `<microservice>-1`, …

---

> Готово! Если все шаги проходят без ошибок и контейнеры работают, инфраструктура создана корректно.
