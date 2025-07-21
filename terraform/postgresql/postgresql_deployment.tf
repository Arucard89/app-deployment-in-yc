# Настройка провайдера
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = ">= 0.72.0"
    }
  }
  required_version = ">= 1.3"
}

provider "yandex" {
  zone = var.default_zone
}

# Получение данных из базовой инфраструктуры
data "yandex_vpc_network" "app_network" {
  network_id = var.network_id
}

data "yandex_vpc_subnet" "app_subnet" {
  subnet_id = var.subnet_id
}

data "yandex_vpc_security_group" "app_sg" {
  security_group_id = var.security_group_id
}

# Создание специальной группы безопасности для PostgreSQL
resource "yandex_vpc_security_group" "postgresql_sg" {
  name        = "postgresql-security-group"
  description = "Security group for PostgreSQL"
  network_id  = data.yandex_vpc_network.app_network.id

  # SSH доступ
  ingress {
    protocol       = "TCP"
    description    = "SSH access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  # PostgreSQL доступ только из внутренней сети
  ingress {
    protocol       = "TCP"
    description    = "PostgreSQL access from internal network"
    v4_cidr_blocks = ["10.1.0.0/24"]
    port           = 5432
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание секретов в Yandex Lockbox
resource "yandex_lockbox_secret" "postgresql_secrets" {
  name        = "postgresql-secrets"
  description = "PostgreSQL passwords and connection strings"
  
  deletion_protection = true
}

# Создание версии секрета с паролями
resource "yandex_lockbox_secret_version" "postgresql_secrets_version" {
  secret_id = yandex_lockbox_secret.postgresql_secrets.id
  entries {
    key        = "app_user_password"
    text_value = random_password.app_user_password.result
  }
  entries {
    key        = "app_readonly_password"
    text_value = random_password.app_readonly_password.result
  }
  entries {
    key        = "postgres_password"
    text_value = random_password.postgres_password.result
  }
}

# Генерация случайных паролей
resource "random_password" "app_user_password" {
  length  = 32
  special = true
}

resource "random_password" "app_readonly_password" {
  length  = 32
  special = true
}

resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

# Создание сервисного аккаунта для PostgreSQL
resource "yandex_iam_service_account" "postgresql_sa" {
  name        = "postgresql-sa"
  description = "Service account for PostgreSQL"
}

# Роли для сервисного аккаунта
resource "yandex_resourcemanager_folder_iam_member" "postgresql_sa_compute_editor" {
  folder_id = var.folder_id
  role      = "compute.editor"
  member    = "serviceAccount:${yandex_iam_service_account.postgresql_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "postgresql_sa_lockbox_viewer" {
  folder_id = var.folder_id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.postgresql_sa.id}"
}

# Получение образа Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Создание SSH ключей для PostgreSQL
resource "tls_private_key" "postgresql_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Создание VPS для PostgreSQL
resource "yandex_compute_instance" "postgresql" {
  name        = "postgresql-server"
  description = "PostgreSQL 17 server"
  zone        = var.default_zone
  
  resources {
    cores         = 2
    memory        = 6
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 80
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.app_subnet.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.postgresql_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.postgresql_ssh_key.public_key_openssh}"
    user-data = templatefile("${path.module}/postgresql-cloud-init.yaml", {
      ssh_key = tls_private_key.postgresql_ssh_key.public_key_openssh
      app_user_password = random_password.app_user_password.result
      app_readonly_password = random_password.app_readonly_password.result
      postgres_password = random_password.postgres_password.result
    })
  }

  service_account_id = yandex_iam_service_account.postgresql_sa.id
}

# Создание скрипта подключения к PostgreSQL
resource "local_file" "connect_script" {
  filename = "${path.module}/connect_to_postgresql.sh"
  content = templatefile("${path.module}/connect_script.tpl", {
    postgresql_ip = yandex_compute_instance.postgresql.network_interface.0.ip_address
    ssh_key_path = "postgresql_ssh_key.pem"
  })
  file_permission = "0755"
}

# Сохранение приватного ключа SSH
resource "local_file" "postgresql_ssh_private_key" {
  filename = "${path.module}/postgresql_ssh_key.pem"
  content  = tls_private_key.postgresql_ssh_key.private_key_pem
  file_permission = "0600"
}

# Создание документации для разработчиков
resource "local_file" "developer_documentation" {
  filename = "${path.module}/developer_db_access.md"
  content = templatefile("${path.module}/developer_docs.tpl", {
    postgresql_ip = yandex_compute_instance.postgresql.network_interface.0.ip_address
    app_user_password = random_password.app_user_password.result
    app_readonly_password = random_password.app_readonly_password.result
  })
}

# Вывод информации
output "postgresql_internal_ip" {
  value = yandex_compute_instance.postgresql.network_interface.0.ip_address
}

output "postgresql_security_group_id" {
  value = yandex_vpc_security_group.postgresql_sg.id
}

output "lockbox_secret_id" {
  value = yandex_lockbox_secret.postgresql_secrets.id
}
