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
```javascript
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
    const result = await client.query('SELECT * FROM users');
    return result.rows;
  } finally {
    client.release();
  }
}
```

### Python (с psycopg2)
```python
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
        cursor.execute("SELECT * FROM users")
        return cursor.fetchall()
    finally:
        connection_pool.putconn(conn)
```

### Go (с lib/pq)
```go
package main

import (
    "database/sql"
    _ "github.com/lib/pq"
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

```bash
export DB_HOST="${postgresql_ip}"
export DB_PORT="5432"
export DB_NAME="app_db"
export DB_USER="app_user"
export DB_PASSWORD="${app_user_password}"
export DB_READONLY_USER="app_readonly"
export DB_READONLY_PASSWORD="${app_readonly_password}"
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