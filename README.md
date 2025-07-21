### README.md

```markdown
# Инфраструктура PostgreSQL на Yandex Cloud

Этот проект содержит полный набор Terraform скриптов для развертывания безопасной и масштабируемой инфраструктуры PostgreSQL на Yandex Cloud.

## Архитектура

### Компоненты системы:

- **VPC сеть** с приватными подсетями (10.1.0.0/24)
- **NAT Gateway** для доступа в интернет
- **Security Groups** с минимальными правами
- **4 VPS** для микросервисов (Frontend, API, Main, Billing+Mail)
- **1 VPS** для PostgreSQL 17
- **Yandex Lockbox** для хранения секретов
- **Автоматические backup'ы** с ротацией
- **Мониторинг** и алерты

### Безопасность:

- SSH доступ только по ключам
- PostgreSQL доступен только из внутренней сети
- Fail2ban защита от атак
- UFW Firewall
- Секреты в Yandex Lockbox

## Быстрый старт

### Предварительные требования:

1. Terraform >= 1.3
2. Yandex Cloud CLI
3. Настроенный доступ к Yandex Cloud

### Установка:

1. **Клонирование репозитория:**
```

git clone <repository-url>
cd postgresql-yandex-infrastructure

```

2. **Настройка переменных:**
```

export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=\$(yc config get folder-id)

```

3. **Развертывание базовой инфраструктуры:**
```

cd infrastructure
terraform init
terraform plan -var="folder_id=$YC_FOLDER_ID"
terraform apply -var="folder_id=$YC_FOLDER_ID"

```

4. **Развертывание PostgreSQL:**
```

cd ../postgresql
terraform init
terraform plan -var="folder_id=\$YC_FOLDER_ID" -var="network_id=<network_id>" -var="subnet_id=<subnet_id>" -var="security_group_id=<security_group_id>"
terraform apply

```

### Использование:

1. **Подключение к PostgreSQL:**
```

# Из директории postgresql

./connect_to_postgresql.sh

```

2. **Настройка backup'ов:**
```

# Запуск скрипта backup'а

./postgresql_backup.sh

```

3. **Мониторинг:**
```

# Запуск мониторинга

./postgresql_monitor.sh

```

## Структура проекта

```

.
├── infrastructure/
│ ├── infrastructure_deployment.tf
│ ├── variables.tf
│ ├── cloud-init.yaml
│ └── deployment_vars.tpl
├── postgresql/
│ ├── postgresql_deployment.tf
│ ├── postgresql-cloud-init.yaml
│ ├── variables.tf
│ └── templates/
├── backup/
│ ├── postgresql_backup.tf
│ ├── backup_script.tpl
│ └── monitor_script.tpl
└── README.md

```

## Конфигурация

### PostgreSQL настройки:
- Версия: PostgreSQL 17
- Оптимизация для продакшена
- Автоматические backup'ы в 2:00
- Ротация backup'ов: 7 дней

### Безопасность:
- Доступ к PostgreSQL только из сети 10.1.0.0/24
- SSH ключи для всех серверов
- Fail2ban для защиты от атак
- UFW Firewall

### Мониторинг:
- Проверка доступности каждые 15 минут
- Метрики производительности
- Еженедельные отчеты

## Документация для разработчиков

### Строки подключения:

**Для приложений (app_user):**
```

Host: <postgresql_internal_ip>
Port: 5432
Database: app_db
Username: app_user
Password: <хранится в Yandex Lockbox>

```

**Для чтения (app_readonly):**
```

Host: <postgresql_internal_ip>
Port: 5432
Database: app_db
Username: app_readonly
Password: <хранится в Yandex Lockbox>

```

### Примеры подключения:

**Node.js:**
```

const { Pool } = require('pg');

const pool = new Pool({
host: '<postgresql_internal_ip>',
port: 5432,
database: 'app_db',
user: 'app_user',
password: '<password_from_lockbox>',
ssl: false
});

```

**Python:**
```

import psycopg2

conn = psycopg2.connect(
host="<postgresql_internal_ip>",
port=5432,
database="app_db",
user="app_user",
password="<password_from_lockbox>"
)

```

## Управление инфраструктурой

### Добавление новых SSH ключей:
1. Добавить ключ в переменную ssh_keys в cloud-init.yaml
2. Выполнить `terraform apply`

### Масштабирование:
- Увеличение ресурсов VPS: изменить переменные в variables.tf
- Добавление новых микросервисов: дополнить конфигурацию в переменной microservices

### Backup и восстановление:
- Backup'ы создаются автоматически в 2:00 каждый день
- Восстановление: `./postgresql_restore.sh <backup_file>`

## Troubleshooting

### Проблемы с подключением:
1. Проверить статус PostgreSQL: `systemctl status postgresql`
2. Проверить настройки firewall: `ufw status`
3. Проверить логи: `tail -f /var/log/postgresql/postgresql-*.log`

### Проблемы с производительностью:
1. Проверить активные соединения: `SELECT * FROM pg_stat_activity;`
2. Проверить медленные запросы: `SELECT * FROM pg_stat_statements;`
3. Проверить использование диска: `df -h`

## Поддержка

Для получения поддержки:
1. Проверьте логи мониторинга: `/var/log/postgresql_monitor.log`
2. Запустите диагностику: `./postgresql_monitor.sh`
3. Проверьте еженедельные отчеты: `/var/log/postgresql_weekly_report_*.txt`

## Лицензия

Этот проект распространяется под лицензией MIT.
```

### developer_docs.tpl

```markdown
# Документация для разработчиков - Доступ к PostgreSQL

## Информация о подключении

### Основные параметры:

- **Хост**: ${postgresql_ip}
- **Порт**: 5432
- **База данных**: app_db

### Пользователи:

#### app_user (полный доступ)

- **Пользователь**: app_user
- **Пароль**: ${app_user_password}
- **Права**: Полный доступ к базе данных app_db

#### app_readonly (только чтение)

- **Пользователь**: app_readonly
- **Пароль**: ${app_readonly_password}
- **Права**: Только чтение из базы данных app_db

## Примеры подключения

### Node.js (с pg)
```

const { Pool } = require('pg');

const pool = new Pool({
host: '${postgresql_ip}',
  port: 5432,
  database: 'app_db',
  user: 'app_user',
  password: '${app_user_password}',
ssl: false,
max: 20,
idleTimeoutMillis: 30000,
connectionTimeoutMillis: 2000,
});

// Пример использования
async function getUsers() {
const client = await pool.connect();
try {
const result = await client.query('SELECT \* FROM users');
return result.rows;
} finally {
client.release();
}
}

```

### Python (с psycopg2)
```

import psycopg2
from psycopg2.pool import SimpleConnectionPool

# Создание пула соединений

connection_pool = SimpleConnectionPool(
1, 20,
host='${postgresql_ip}',
    port=5432,
    database='app_db',
    user='app_user',
    password='${app_user_password}'
)

# Пример использования

def get_users():
conn = connection_pool.getconn()
try:
cursor = conn.cursor()
cursor.execute("SELECT \* FROM users")
return cursor.fetchall()
finally:
connection_pool.putconn(conn)

```

### Go (с lib/pq)
```

package main

import (
"database/sql"
\_ "github.com/lib/pq"
)

func main() {
db, err := sql.Open("postgres",
"host=${postgresql_ip} port=5432 user=app_user password=${app_user_password} dbname=app_db sslmode=disable")
if err != nil {
panic(err)
}
defer db.Close()

    // Пример использования
    rows, err := db.Query("SELECT * FROM users")
    if err != nil {
        panic(err)
    }
    defer rows.Close()
    }

```

## Рекомендации по безопасности

1. **Используйте пользователя app_readonly** для операций чтения
2. **Не передавайте пароли в открытом виде** - используйте переменные окружения
3. **Используйте пулы соединений** для оптимизации производительности
4. **Всегда закрывайте соединения** после использования

## Переменные окружения

Рекомендуется использовать переменные окружения для хранения паролей:

```

export DB_HOST="${postgresql_ip}"
export DB_PORT="5432"
export DB_NAME="app_db"
export DB_USER="app_user"
export DB_PASSWORD="${app_user_password}"
export DB_READONLY_USER="app_readonly"
export DB_READONLY_PASSWORD="\${app_readonly_password}"

```

## Troubleshooting

### Проблемы с подключением:
1. Убедитесь, что ваш сервер находится в той же сети (10.1.0.0/24)
2. Проверьте, что PostgreSQL сервер доступен: `telnet ${postgresql_ip} 5432`
3. Проверьте правильность учетных данных

### Проблемы с производительностью:
1. Используйте индексы для часто запрашиваемых полей
2. Оптимизируйте запросы с помощью EXPLAIN
3. Используйте пулы соединений
4. Мониторьте медленные запросы

### Получение помощи:
- Логи PostgreSQL: `/var/log/postgresql/postgresql-*.log`
- Мониторинг: `/var/log/postgresql_monitor.log`
- Еженедельные отчеты: `/var/log/postgresql_weekly_report_*.txt`
```
