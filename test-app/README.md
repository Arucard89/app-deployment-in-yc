# Test Hello World Application

Простое тестовое веб-приложение для проверки работы Container Registry и автоматического развертывания в Yandex Cloud.

## Содержимое

- **`index.html`** - Красивая HTML страница "Hello World" с CSS анимацией и информацией о системе
- **`nginx.conf`** - Конфигурация nginx с security headers и healthcheck endpoint
- **`Dockerfile`** - Мультиплатформенный Docker образ на базе nginx:alpine

## Особенности

- 🎨 **Современный дизайн** с градиентным фоном и glass morphism эффектом
- 🚀 **Мультиплатформенность** - работает на ARM64 (M1/M2/M3 Mac) и x86_64 (серверы)
- 🛡️ **Безопасность** - запуск от непривилегированного пользователя, security headers
- 💚 **Health checks** - endpoint `/health` для мониторинга Docker контейнера
- ⚡ **Оптимизация** - кеширование статических файлов, сжатие gzip

## Локальная сборка и тестирование

```bash
# Сборка образа
docker build -t test-hello-world:local .

# Запуск контейнера
docker run -d --name test-app -p 8080:80 test-hello-world:local

# Открытие в браузере
open http://localhost:8080

# Проверка health endpoint
curl http://localhost:8080/health

# Остановка
docker stop test-app && docker rm test-app
```

## Полная инструкция по развертыванию

См. файл `DEPLOY_INSTRUCTIONS.md` в корне проекта.

---

**Результат:** Веб-приложение отобразит красивую страницу "Hello World" с информацией о системе и временем загрузки.
