#!/bin/bash
# PostgreSQL Restore Script
# Восстановление базы данных из backup'а

set -e

# Конфигурация
POSTGRESQL_IP="${postgresql_ip}"
DB_NAME="app_db"
BACKUP_DIR="/var/backups/postgresql"
LOG_FILE="/var/log/postgresql_restore.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Функция восстановления из backup'а
restore_backup() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        echo "Usage: $0 <backup_file>"
        echo "Available backups:"
        ls -la "$BACKUP_DIR"/app_db_*.sql.gz 2>/dev/null || echo "No backups found"
        exit 1
    fi

    if [ ! -f "$backup_file" ]; then
        log "ERROR: Backup file not found: $backup_file"
        exit 1
    fi

    log "Starting restore from backup: $backup_file"

    # Проверка целостности backup'а
    if ! gunzip -t "$backup_file" 2>/dev/null; then
        log "ERROR: Backup file is corrupted: $backup_file"
        exit 1
    fi

    # Создание резервной копии текущей базы данных
    local current_backup="/tmp/app_db_before_restore_$(date +%Y%m%d_%H%M%S).sql.gz"
    log "Creating backup of current database: $current_backup"
    
    if ! ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres pg_dump $DB_NAME" | gzip > "$current_backup"; then
        log "ERROR: Failed to create current database backup"
        exit 1
    fi

    # Остановка всех подключений к базе данных
    log "Terminating all connections to database $DB_NAME"
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();\""

    # Удаление текущей базы данных
    log "Dropping current database $DB_NAME"
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres dropdb $DB_NAME"

    # Создание новой базы данных
    log "Creating new database $DB_NAME"
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres createdb $DB_NAME"

    # Восстановление из backup'а
    log "Restoring database from backup"
    if gunzip -c "$backup_file" | ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql $DB_NAME"; then
        log "Database restored successfully from: $backup_file"
        log "Current database backup saved to: $current_backup"
    else
        log "ERROR: Failed to restore database"
        log "Attempting to restore from current backup: $current_backup"
        
        # Попытка восстановления из текущего backup'а
        ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres dropdb $DB_NAME"
        ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres createdb $DB_NAME"
        gunzip -c "$current_backup" | ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql $DB_NAME"
        
        log "Original database restored from current backup"
        exit 1
    fi

    # Восстановление прав доступа
    log "Restoring database permissions"
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO app_user;\""
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -c \"GRANT CONNECT ON DATABASE $DB_NAME TO app_readonly;\""
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -d $DB_NAME -c \"GRANT USAGE ON SCHEMA public TO app_readonly;\""
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -d $DB_NAME -c \"GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;\""
    ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -d $DB_NAME -c \"ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_readonly;\""

    log "Database restore completed successfully"
}

# Главная функция
main() {
    local backup_file=$1
    
    log "PostgreSQL restore script started"
    
    # Проверка подключения к PostgreSQL
    if ! ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -c 'SELECT version();'" &>/dev/null; then
        log "ERROR: Cannot connect to PostgreSQL server"
        exit 1
    fi

    # Восстановление из backup'а
    restore_backup "$backup_file"
    
    log "PostgreSQL restore script completed"
}

# Запуск скрипта
main "$@" 