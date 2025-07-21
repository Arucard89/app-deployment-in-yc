#!/bin/bash
# PostgreSQL Backup Script
# Автоматическое создание backup'ов и их ротация

set -e

# Конфигурация
POSTGRESQL_IP="${postgresql_ip}"
DB_NAME="app_db"
BACKUP_DIR="/var/backups/postgresql"
BACKUP_RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/app_db_$TIMESTAMP.sql.gz"
LOG_FILE="/var/log/postgresql_backup.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Создание директории для backup'ов
mkdir -p "$BACKUP_DIR"

# Функция создания backup'а
create_backup() {
    log "Starting backup of database $DB_NAME"

    # Создание backup'а
    if ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres pg_dump $DB_NAME" | gzip > "$BACKUP_FILE"; then
        log "Backup created successfully: $BACKUP_FILE"

        # Проверка размера backup'а
        BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE")
        log "Backup size: $BACKUP_SIZE bytes"

        # Проверка целостности backup'а
        if gunzip -t "$BACKUP_FILE" 2>/dev/null; then
            log "Backup integrity check passed"
        else
            log "ERROR: Backup integrity check failed"
            exit 1
        fi
    else
        log "ERROR: Failed to create backup"
        exit 1
    fi
}

# Функция ротации backup'ов
rotate_backups() {
    log "Starting backup rotation (retention: $BACKUP_RETENTION_DAYS days)"

    # Удаление старых backup'ов
    find "$BACKUP_DIR" -name "app_db_*.sql.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete

    # Подсчет оставшихся backup'ов
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "app_db_*.sql.gz" -type f | wc -l)
    log "Remaining backups: $BACKUP_COUNT"
}

# Функция отправки уведомлений
send_notification() {
    local status=$1
    local message=$2

    # Здесь можно добавить отправку уведомлений
    # Например, через webhook или email
    log "Notification: $status - $message"
}

# Главная функция
main() {
    log "PostgreSQL backup script started"

    # Проверка подключения к PostgreSQL
    if ! ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -c 'SELECT version();'" &>/dev/null; then
        log "ERROR: Cannot connect to PostgreSQL server"
        send_notification "ERROR" "Cannot connect to PostgreSQL server"
        exit 1
    fi

    # Создание backup'а
    create_backup

    # Ротация backup'ов
    rotate_backups

    # Отправка уведомления об успешном backup'е
    send_notification "SUCCESS" "Database backup completed successfully"

    log "PostgreSQL backup script completed"
}

# Запуск скрипта
main "$@" 