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
  # Стандартные метки
  timestamp           = formatdate("YYYY-MM-DD-hhmm", timestamp())
  network_name        = "app-network"
  subnet_name         = "app-subnet"
  security_group_name = "app-security-group"
  nat_gateway_name    = "app-nat-gateway"
  route_table_name    = "app-route-table"

  # Если переменная `existing_network_id` задана, используем уже созданную сеть
  use_existing_network = var.existing_network_id != ""

  # Итоговый ID сети (созданной в рамках apply либо существующей)
  effective_network_id = local.use_existing_network ? var.existing_network_id : yandex_vpc_network.app_network[0].id
  
  # ----- Подсеть -----
  use_existing_subnet   = var.existing_subnet_id != ""
  effective_subnet_id   = local.use_existing_subnet ? var.existing_subnet_id : yandex_vpc_subnet.app_subnet[0].id

  # ----- NAT Gateway -----
  use_existing_nat_gateway = var.existing_nat_gateway_id != ""
  effective_nat_gateway_id = local.use_existing_nat_gateway ? var.existing_nat_gateway_id : yandex_vpc_gateway.nat_gateway[0].id

  # ----- Route table -----
  use_existing_route_table = var.existing_route_table_id != ""
  effective_route_table_id = local.use_existing_route_table ? var.existing_route_table_id : yandex_vpc_route_table.app_route_table[0].id

  # ----- Security group -----
  use_existing_security_group = var.existing_security_group_id != ""
  effective_security_group_id = local.use_existing_security_group ? var.existing_security_group_id : yandex_vpc_security_group.app_sg[0].id
 
  # Сохранение переменных в файл
  deployment_vars = {
    timestamp = local.timestamp
    network_id = local.effective_network_id
    subnet_id = local.effective_subnet_id
    security_group_id = local.effective_security_group_id
    nat_gateway_id = local.effective_nat_gateway_id
    route_table_id = local.effective_route_table_id
    microservices_ips = {
      for key, instance in yandex_compute_instance.microservices : key => instance.network_interface.0.ip_address
    }
  }
}

# Создание VPC сети
resource "yandex_vpc_network" "app_network" {
  # Если сеть уже есть — пропускаем создание.
  count       = local.use_existing_network ? 0 : 1
  name        = local.network_name
  description = "App network for microservices"
}

# Создание подсети
resource "yandex_vpc_subnet" "app_subnet" {
  count          = local.use_existing_subnet ? 0 : 1
  name           = local.subnet_name
  zone           = var.default_zone
  network_id     = local.effective_network_id
  v4_cidr_blocks = ["10.1.0.0/24"]
  route_table_id = local.effective_route_table_id
}

# Создание NAT Gateway
resource "yandex_vpc_gateway" "nat_gateway" {
  count = local.use_existing_nat_gateway ? 0 : 1
  name = local.nat_gateway_name
  shared_egress_gateway {}
}

# Создание таблицы маршрутизации для NAT Gateway
resource "yandex_vpc_route_table" "app_route_table" {
  count       = local.use_existing_route_table ? 0 : 1
  name       = local.route_table_name
  network_id = local.effective_network_id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = local.effective_nat_gateway_id
  }
}

# Создание группы безопасности
resource "yandex_vpc_security_group" "app_sg" {
  count       = local.use_existing_security_group ? 0 : 1
  name        = local.security_group_name
  description = "Security group for app microservices"
  network_id  = local.effective_network_id

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

# Разрешение вытягивать образы из YCR
resource "yandex_resourcemanager_folder_iam_member" "microservices_sa_cr_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.microservices_sa.id}"
}

# Получение образа Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
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
    subnet_id          = local.effective_subnet_id
    nat                = each.value.nat_enabled
    security_group_ids = [local.effective_security_group_id]
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh_key.public_key_openssh}"
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      ssh_key = tls_private_key.ssh_key.public_key_openssh
      container_images = join(",", each.value.images)
      microservice_name = each.key
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
  value = local.effective_network_id
}

output "subnet_id" {
  value = local.effective_subnet_id
}

output "security_group_id" {
  value = local.effective_security_group_id
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
