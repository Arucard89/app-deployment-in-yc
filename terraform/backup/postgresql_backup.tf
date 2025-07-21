# Создание скрипта backup'а PostgreSQL
resource "local_file" "postgresql_backup_script" {
  filename = "${path.module}/postgresql_backup.sh"
  content = templatefile("${path.module}/backup_script.tpl", {
    postgresql_ip = var.postgresql_ip
  })
  file_permission = "0755"
}

# Создание скрипта мониторинга
resource "local_file" "postgresql_monitor_script" {
  filename = "${path.module}/postgresql_monitor.sh"
  content = templatefile("${path.module}/monitor_script.tpl", {
    postgresql_ip = var.postgresql_ip
  })
  file_permission = "0755"
}

# Создание скрипта восстановления
resource "local_file" "postgresql_restore_script" {
  filename = "${path.module}/postgresql_restore.sh"
  content = templatefile("${path.module}/restore_script.tpl", {
    postgresql_ip = var.postgresql_ip
  })
  file_permission = "0755"
}
