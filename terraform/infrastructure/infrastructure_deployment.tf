# Настройка провайдера Yandex Cloud
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = ">= 0.72.0"
    }
  }
  required_version = ">= 1.3"
}

# Конфигурация провайдера
provider "yandex" {
  zone = var.default_zone
}

# Локальные переменные для удобства
locals {
  timestamp = formatdate("YYYY-MM-DD-hhmm", timestamp())
  network_name = "app-network"
  subnet_name = "app-subnet"
  security_group_name = "app-security-group"
  nat_gateway_name = "app-nat-gateway"
  route_table_name = "app-route-table"
  
  # Сохранение переменных в файл
  deployment_vars = {
    timestamp = local.timestamp
    network_id = yandex_vpc_network.app_network.id
    subnet_id = yandex_vpc_subnet.app_subnet.id
    security_group_id = yandex_vpc_security_group.app_sg.id
    nat_gateway_id = yandex_vpc_gateway.nat_gateway.id
    route_table_id = yandex_vpc_route_table.app_route_table.id
    microservices_ips = {
      for key, instance in yandex_compute_instance.microservices : key => instance.network_interface.0.ip_address
    }
  }
}

# Создание VPC сети
resource "yandex_vpc_network" "app_network" {
  name = local.network_name
  description = "App network for microservices"
}

# Создание подсети
resource "yandex_vpc_subnet" "app_subnet" {
  name           = local.subnet_name
  zone           = var.default_zone
  network_id     = yandex_vpc_network.app_network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
  route_table_id = yandex_vpc_route_table.app_route_table.id
}

# Создание NAT Gateway
resource "yandex_vpc_gateway" "nat_gateway" {
  name = local.nat_gateway_name
  shared_egress_gateway {}
}

# Создание таблицы маршрутизации для NAT Gateway
resource "yandex_vpc_route_table" "app_route_table" {
  name       = local.route_table_name
  network_id = yandex_vpc_network.app_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# Создание группы безопасности
resource "yandex_vpc_security_group" "app_sg" {
  name        = local.security_group_name
  description = "Security group for app microservices"
  network_id  = yandex_vpc_network.app_network.id

  # SSH доступ
  ingress {
    protocol       = "TCP"
    description    = "SSH access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  # HTTP доступ
  ingress {
    protocol       = "TCP"
    description    = "HTTP access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  # HTTPS доступ
  ingress {
    protocol       = "TCP"
    description    = "HTTPS access"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  # Внутренние подключения
  ingress {
    protocol       = "TCP"
    description    = "Internal connections"
    v4_cidr_blocks = ["10.1.0.0/24"]
    from_port      = 1
    to_port        = 65535
  }

  # ICMP доступ (ping)
  ingress {
    protocol       = "ICMP"
    description    = "Allow ICMP (ping) between VPS"
    v4_cidr_blocks = ["10.1.0.0/24"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание сервисных аккаунтов
resource "yandex_iam_service_account" "microservices_sa" {
  name        = "microservices-sa"
  description = "Service account for microservices"
}

# Роли для сервисного аккаунта
resource "yandex_resourcemanager_folder_iam_member" "microservices_sa_compute_viewer" {
  folder_id = var.folder_id
  role      = "compute.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.microservices_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "microservices_sa_lockbox_viewer" {
  folder_id = var.folder_id
  role      = "lockbox.payloadViewer"
  member    = "serviceAccount:${yandex_iam_service_account.microservices_sa.id}"
}

# Дополнительные роли для работы с Container Registry
resource "yandex_resourcemanager_folder_iam_member" "microservices_sa_container_puller" {
  count     = var.enable_container_deployment ? 1 : 0
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.microservices_sa.id}"
}

# Создание секрета в Lockbox для IAM токена
resource "yandex_lockbox_secret" "ycr_credentials" {
  count       = var.enable_container_deployment && var.ycr_iam_token != "" ? 1 : 0
  name        = "ycr-iam-token-${local.timestamp}"
  description = "IAM токен для доступа к Yandex Container Registry"
}

# Версия секрета с IAM токеном
resource "yandex_lockbox_secret_version" "ycr_credentials_version" {
  count     = var.enable_container_deployment && var.ycr_iam_token != "" ? 1 : 0
  secret_id = yandex_lockbox_secret.ycr_credentials[0].id
  entries {
    key        = "iam-token"
    text_value = var.ycr_iam_token
  }
  entries {
    key        = "registry-id"
    text_value = local.final_registry_id != "" ? local.final_registry_id : var.container_registry_id
  }
}

# Локальные переменные для логики Container Registry
locals {
  # Определяем, нужно ли создавать новый реестр
  should_create_registry = var.enable_container_registry && var.existing_container_registry_id == ""
  
  # Получаем финальный ID реестра (существующий или новосозданный)
  final_registry_id = var.enable_container_registry ? (
    var.existing_container_registry_id != "" ? 
    var.existing_container_registry_id : 
    (local.should_create_registry ? yandex_container_registry.app_registry[0].id : "")
  ) : ""
}

# Создание Container Registry только если не используется существующий
resource "yandex_container_registry" "app_registry" {
  count     = local.should_create_registry ? 1 : 0
  name      = var.container_registry_name
  folder_id = var.folder_id
}

# Получение образа Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Создание SSH ключей
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Создание 4 VPS для микросервисов
resource "yandex_compute_instance" "microservices" {
  for_each = var.microservices

  name        = each.key
  description = "VPS for ${each.key} microservice"
  zone        = var.default_zone
  
  resources {
    cores  = each.value.cores
    memory = each.value.memory
    core_fraction = each.value.core_fraction
  }

  platform_id = each.value.platform_id

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = each.value.disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app_subnet.id
    nat                = each.value.nat_enabled
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh_key.public_key_openssh}"
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      ssh_key = tls_private_key.ssh_key.public_key_openssh
      enable_container_deployment = var.enable_container_deployment
      container_image = var.container_image
      app_port = var.app_port
      lockbox_secret_id = var.enable_container_deployment && var.ycr_iam_token != "" ? yandex_lockbox_secret.ycr_credentials[0].id : ""
    })
  }

  service_account_id = yandex_iam_service_account.microservices_sa.id
}

# Сохранение переменных в файл
resource "local_file" "deployment_vars" {
  filename = "${path.module}/${local.timestamp}_deployment_vars.env"
  content = templatefile("${path.module}/deployment_vars.tpl", {
    deployment_vars = local.deployment_vars
  })
}

# Вывод информации
output "network_id" {
  value = yandex_vpc_network.app_network.id
}

output "subnet_id" {
  value = yandex_vpc_subnet.app_subnet.id
}

output "security_group_id" {
  value = yandex_vpc_security_group.app_sg.id
}

output "microservices_ips" {
  value = {
    for key, instance in yandex_compute_instance.microservices : key => {
      internal_ip = instance.network_interface.0.ip_address
      external_ip = instance.network_interface.0.nat_ip_address
    }
  }
}

output "ssh_private_key" {
  value = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

# Outputs для Lockbox и Container Registry
output "lockbox_secret_id" {
  value = var.enable_container_deployment && var.ycr_iam_token != "" ? yandex_lockbox_secret.ycr_credentials[0].id : null
  description = "ID секрета в Yandex Lockbox с IAM токеном для YCR"
}

output "container_deployment_status" {
  value = var.enable_container_deployment ? "enabled" : "disabled"
  description = "Статус автоматического развертывания контейнеров"
}

output "container_image" {
  value = var.container_image
  description = "Образ контейнера для развертывания"
}

# Выходные переменные Container Registry
output "container_registry_id" {
  value       = local.final_registry_id != "" ? local.final_registry_id : null
  description = "ID of created or used Container Registry"
}

output "container_registry_url" {
  value       = local.final_registry_id != "" ? "cr.yandex/${local.final_registry_id}" : null
  description = "Full URL of Container Registry for docker push/pull"
}

output "container_registry_name" {
  value       = var.enable_container_registry ? var.container_registry_name : null
  description = "Name of Container Registry"
}
