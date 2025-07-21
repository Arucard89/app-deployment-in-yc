#!/bin/bash
# PostgreSQL Monitoring Script
# Мониторинг состояния PostgreSQL сервера

set -e

# Конфигурация
POSTGRESQL_IP="${postgresql_ip}"
LOG_FILE="/var/log/postgresql_monitor.log"
METRICS_FILE="/var/log/postgresql_metrics.log"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Функция записи метрик
write_metric() {
    local metric_name=$1
    local metric_value=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$metric_name,$metric_value" >> "$METRICS_FILE"
}

# Проверка доступности PostgreSQL
check_postgresql_availability() {
    log "Checking PostgreSQL availability"
    
    if ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -c 'SELECT 1;'" &>/dev/null; then
        log "PostgreSQL is available"
        write_metric "postgresql_availability" "1"
        return 0
    else
        log "ERROR: PostgreSQL is not available"
        write_metric "postgresql_availability" "0"
        return 1
    fi
}

# Проверка производительности
check_performance() {
    log "Checking PostgreSQL performance"
    
    # Количество активных соединений
    local active_connections=$(ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -t -c \"SELECT count(*) FROM pg_stat_activity WHERE state = 'active';\"" | tr -d ' ')
    write_metric "active_connections" "$active_connections"
    
    # Размер базы данных
    local db_size=$(ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -t -c \"SELECT pg_size_pretty(pg_database_size('app_db'));\"" | tr -d ' ')
    log "Database size: $db_size"
    
    # Проверка долго выполняющихся запросов
    local long_queries=$(ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -t -c \"SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 minutes';\"" | tr -d ' ')
    write_metric "long_running_queries" "$long_queries"
    
    if [ "$long_queries" -gt 0 ]; then
        log "WARNING: Found $long_queries long-running queries"
    fi
}

# Проверка места на диске
check_disk_space() {
    log "Checking disk space"
    
    local disk_usage=$(ssh ubuntu@$POSTGRESQL_IP "df -h /var/lib/postgresql | tail -1 | awk '{print \$5}' | sed 's/%//g'")
    write_metric "disk_usage_percent" "$disk_usage"
    
    if [ "$disk_usage" -gt 80 ]; then
        log "WARNING: Disk usage is $disk_usage%"
    fi
}

# Проверка статуса сервисов
check_services() {
    log "Checking service status"
    
    # PostgreSQL
    if ssh ubuntu@$POSTGRESQL_IP "systemctl is-active postgresql" &>/dev/null; then
        write_metric "postgresql_service_status" "1"
    else
        write_metric "postgresql_service_status" "0"
        log "ERROR: PostgreSQL service is not active"
    fi
    
    # Fail2ban
    if ssh ubuntu@$POSTGRESQL_IP "systemctl is-active fail2ban" &>/dev/null; then
        write_metric "fail2ban_service_status" "1"
    else
        write_metric "fail2ban_service_status" "0"
        log "WARNING: Fail2ban service is not active"
    fi
}

# Генерация еженедельного отчета
generate_weekly_report() {
    log "Generating weekly report"
    
    local report_file="/var/log/postgresql_weekly_report_$(date +%Y%m%d).txt"
    
    cat > "$report_file" << EOF
PostgreSQL Weekly Report - $(date)
====================================

System Status:
- PostgreSQL Service: $(ssh ubuntu@$POSTGRESQL_IP "systemctl is-active postgresql")
- Fail2ban Service: $(ssh ubuntu@$POSTGRESQL_IP "systemctl is-active fail2ban")

Database Information:
- Database Size: $(ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -t -c \"SELECT pg_size_pretty(pg_database_size('app_db'));\"")
- Active Connections: $(ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -t -c \"SELECT count(*) FROM pg_stat_activity WHERE state = 'active';\"")
- Total Connections: $(ssh ubuntu@$POSTGRESQL_IP "sudo -u postgres psql -t -c \"SELECT count(*) FROM pg_stat_activity;\"")

Performance Metrics (Last 7 Days):
- Average Active Connections: $(awk -F',' '$2=="active_connections" {sum+=$3; count++} END {print sum/count}' "$METRICS_FILE")
- Peak Disk Usage: $(awk -F',' '$2=="disk_usage_percent" {if($3>max) max=$3} END {print max"%"}' "$METRICS_FILE")

System Resources:
- CPU Usage: $(ssh ubuntu@$POSTGRESQL_IP "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1")%
- Memory Usage: $(ssh ubuntu@$POSTGRESQL_IP "free | grep Mem | awk '{printf \"%.2f\", \$3/\$2 * 100.0}'")%
- Disk Usage: $(ssh ubuntu@$POSTGRESQL_IP "df -h /var/lib/postgresql | tail -1 | awk '{print \$5}'")

Recommendations:
$(if [ $(awk -F',' '$2=="active_connections" {if($3>max) max=$3} END {print max}' "$METRICS_FILE") -gt 80 ]; then echo "- Consider increasing max_connections"; fi)
$(if [ $(awk -F',' '$2=="disk_usage_percent" {if($3>max) max=$3} END {print max}' "$METRICS_FILE") -gt 80 ]; then echo "- Consider increasing disk space"; fi)
EOF
    
    log "Weekly report generated: $report_file"
}

# Главная функция
main() {
    log "PostgreSQL monitoring started"
    
    # Базовые проверки
    check_postgresql_availability
    check_performance
    check_disk_space
    check_services
    
    # Генерация еженедельного отчета (по воскресеньям)
    if [ "$(date +%u)" -eq 7 ]; then
        generate_weekly_report
    fi
    
    log "PostgreSQL monitoring completed"
}

# Запуск скрипта
main "$@"
