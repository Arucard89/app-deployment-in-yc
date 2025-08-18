variable "folder_id" {
  description = "Folder ID в Yandex Cloud"
  type        = string
}

variable "default_zone" {
  description = "Зона доступности по умолчанию"
  type        = string
  default     = "ru-central1-a"
}

variable "microservices" {
  description = "Конфигурация микросервисов"
  type = map(object({
    cores     = number
    memory    = number
    disk_size = number
    core_fraction = number
    nat_enabled = bool
    platform_id = string
    image = string
  }))
  default = {
    frontend = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = true
      core_fraction = 50
      platform_id = "standard-v2"
      image = "cr.yandex/your-registry/frontend:latest"
    }
    api = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = false
      core_fraction = 20
      platform_id = "standard-v2"
      image = "cr.yandex/your-registry/api:latest"
    }
    main = {
      cores     = 2
      memory    = 4
      disk_size = 20
      core_fraction = 50
      nat_enabled = false
      platform_id = "standard-v2"
      image = "cr.yandex/your-registry/main:latest"
    }
    billing-mail = {
      cores     = 2
      memory    = 4
      disk_size = 30
      nat_enabled = false
      core_fraction = 20
      platform_id = "standard-v2"
      image = "cr.yandex/your-registry/billing-mail:latest"
    }
  }
}

# Опционально укажите ID уже существующей VPC-сети.  
# Если значение непустое, Terraform пропустит создание новой сети и будет  
# использовать указанную.
variable "existing_network_id" {
  description = "ID существующей VPC сети, которую нужно использовать вместо создания новой."
  type        = string
  default     = ""
}

# Опциональный ID существующей подсети
variable "existing_subnet_id" {
  description = "ID существующей подсети, если не нужно создавать новую."
  type        = string
  default     = ""
}

# Опциональный ID существующего NAT Gateway
variable "existing_nat_gateway_id" {
  description = "ID существующего NAT Gateway, если не нужно создавать новый."
  type        = string
  default     = ""
}

# Опционционный ID существующей таблицы маршрутизации
variable "existing_route_table_id" {
  description = "ID существующей таблицы маршрутизации, если не нужно создавать новую."
  type        = string
  default     = ""
}

# Опционционный ID существующей группы безопасности
variable "existing_security_group_id" {
  description = "ID существующей VPC security group, если не нужно создавать новую."
  type        = string
  default     = ""
}
