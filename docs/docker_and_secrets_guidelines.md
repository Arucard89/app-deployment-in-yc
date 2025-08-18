# Руководство: запуск Docker-контейнеров и работа с секретами в инфраструктуре

> Документ фиксирует решения и рекомендации, которые были проработаны в диалоге **июль 2025**. Применимо к репозиторию `app-deployment-in-yc`.

---

## 1. Обзор текущей инфраструктуры

- Terraform модули:
  - `state_bucket/` — бакет Yandex Object Storage для state-файлов.
  - `infrastructure/` — сеть, NAT, security-group, **4 VPS** для микросервисов.
  - `postgresql/` — отдельная VPS PostgreSQL 17 + Lockbox-секреты.
  - `backup/` — скрипты backup/monitor/restore.
- Все VPS получают конфигурацию через `cloud-init.yaml` (установка Docker, fail2ban, ufw …).

---

## 2. Запуск микросервисов в Docker

### 2.1 Переменные Terraform

| Переменная              | Тип           | Назначение                                                                                                                                       |
| ----------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `microservices`         | `map(object)` | Описание VPS. Добавлены поля:<br> `images list(string)` — список тегов контейнеров<br> `platform_id`, `cores`, `memory` — остались без изменений |
| `container_registry_id` | `string`      | Префикс реестра Yandex CR, напр. `cr.yandex/abcd1234`                                                                                            |

Пример значения для `microservices.billing-mail`:

```hcl
billing-mail = {
  cores  = 2
  memory = 4
  images = [
    "billing:latest",
    "mail:latest"
  ]
}
```

### 2.2 cloud-init: логика запуска контейнеров

```yaml
runcmd:
  # … systemctl enable docker, ufw …
  - |
    # 1. Чистим старые контейнеры
    if [ "$(docker ps -aq)" ]; then
      docker rm -f $(docker ps -aq)
    fi

    # 2. Запускаем перечень образов
    IFS=',' read -ra imgs <<< "${container_images}"
    idx=0
    for img in "${imgs[@]}"; do
      docker pull "$img"
      cname="${microservice_name}-${idx}"
      docker run -d --name "$cname" --restart unless-stopped "$img"
      idx=$((idx+1))
    done
```

- `container_images` — CSV-строка, строится в `infrastructure_deployment.tf`:
  ```hcl
  container_images = join(",", [for img in each.value.images : "${var.container_registry_id}/${img}"])
  ```
- Добавлена IAM-роль `container-registry.images.puller` для SA `microservices-sa`.

### 2.3 Особенности `billing-mail`

VPS «billing-mail» получает два образа, оба запускаются на одной машине с именами `billing-mail-0`, `billing-mail-1`.

---

## 3. Интеграция секретов из Yandex Lockbox

Ниже четыре проверенных подхода.

### 3.1 Вариант 1: ENV-файл в cloud-init

1. cloud-init вытягивает секрет через IAM-токен метаданных.
2. Создаёт `/opt/env/<service>` с парами `KEY=VALUE`.
3. `docker run … --env-file` подключает файл.

**Плюсы**: просто, без изменений кода.

**Минусы**: файл остаётся на диске; для auto-restart контейнера файл должен существовать.

**Примечание**: можно удалить файл после `docker run`, если не используется `--restart` или секрет передаётся через `-e VAR=…`.

### 3.2 Вариант 2: tmpfs + файловые секреты

Секреты складываются в `/run/secrets` (tmpfs), монтируются read-only в контейнер. Высший уровень защиты от письма на диск, но приложение должно читать файлы.

### 3.3 Вариант 3: sidecar-puller

Отдельный контейнер `lockbox-puller` периодически обновляет секрет в общем томе `secret-vol`, основной контейнер использует том read-only. Даёт авто-ротацию без кода, но нужен puller-образ.

### 3.4 Вариант 4: код/entrypoint сам тянет Lockbox

- В `cloud-init` контейнеру передаётся только `LOCKBOX_ID` (и при желании `LOCKBOX_KEYS`).
- Первый процесс в контейнере (`entrypoint.sh`) делает:
  1. GET `169.254.169.254/…/token` → IAM-токен
  2. GET Lockbox `/secrets/<id>/payload`
  3. Экспорт необходимых переменных
  4. `exec` основное приложение

Пример `entrypoint.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
IAM_TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" | jq -r .access_token)
PAYLOAD=$(curl -s -H "Authorization: Bearer $IAM_TOKEN" \
  "https://lockbox.api.cloud.yandex.net/lockbox/v1/secrets/${LOCKBOX_ID}/payload")
export DB_PASSWORD=$(echo "$PAYLOAD" | jq -r '.entries[] | select(.key=="postgres_password") | .textValue')
exec "$@"
```

`Dockerfile` добавляет `ENTRYPOINT ["/entrypoint.sh"]`.

**Плюсы**: секрет не хранится на диске; легко реализовать авто-ротацию в самом приложении.

**Минусы**: нужен код или скрипт в каждом сервисе; надо обрабатывать ошибки сети.

---

## 4. Рекомендации по выбору метода секретов

| Критерий         | ENV-файл | tmpfs    | sidecar | in-app |
| ---------------- | -------- | -------- | ------- | ------ |
| Изменения в коде | нет      | возможно | нет     | да     |
| Секрет на диске  | да       | нет      | да/нет  | нет    |
| Авто-ротация     | вручную  | вручную  | да      | да     |
| Простота         | ★★★★     | ★★★      | ★★      | ★★     |
| Безопасность     | 3/5      | 4/5      | 4/5     | 5/5    |

- **MVP/простая эксплуатация** — ENV-файл.
- **Нет записи на диск** — tmpfs.
- **Регулярная смена паролей** — sidecar или entrypoint.

---

## 5. Дальнейшие шаги

1. Решить, какой метод секретов выбрать для production.
2. Доработать `cloud-init.yaml` и/или Docker-образы согласно выбранному варианту.
3. Обновить `README.md` с инструкциями по переменным `container_registry_id` и `lockbox_secret_id`.
4. Добавить автоматические тесты запуска контейнеров после `terraform apply`.

---

> Документ подготовлен автоматически в рамках обсуждения.
