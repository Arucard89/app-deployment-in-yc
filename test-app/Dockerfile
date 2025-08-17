# Мультиплатформенный Dockerfile для nginx
# Поддерживает ARM64 (M1/M2/M3 Mac) и x86_64 (серверы Yandex Cloud)

FROM nginx:1.25-alpine

# Метаданные образа
LABEL maintainer="test-app"
LABEL description="Simple Hello World web application with nginx"
LABEL version="1.0.0"

# Создание пользователя nginx (если не существует)
RUN addgroup -g 101 -S nginx 2>/dev/null || true && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx 2>/dev/null || true

# Копирование кастомной HTML страницы
COPY index.html /usr/share/nginx/html/index.html

# Создание кастомной конфигурации nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Проверка корректности конфигурации nginx
RUN nginx -t

# Установка правильных прав доступа
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Переключение на непривилегированного пользователя
USER nginx

# Открытие порта 80
EXPOSE 80

# Проверка здоровья контейнера
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Запуск nginx
CMD ["nginx", "-g", "daemon off;"] 