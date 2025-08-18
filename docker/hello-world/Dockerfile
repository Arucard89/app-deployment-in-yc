# Проверочный образ: статическая страница Hello World
FROM nginx:1.25-alpine
LABEL maintainer="infra-team"

# Копируем страницу
COPY index.html /usr/share/nginx/html/index.html

# Простой healthcheck
HEALTHCHECK CMD wget -qO- http://localhost/ || exit 1
