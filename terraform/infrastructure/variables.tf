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
  }))
  default = {
    frontend = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = true
      core_fraction = 50
      platform_id = "standard-v2"
    }
    api = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = false
      core_fraction = 20
      platform_id = "standard-v2"
    }
    main = {
      cores     = 2
      memory    = 4
      disk_size = 20
      core_fraction = 50
      nat_enabled = false
      platform_id = "standard-v2"
    }
    billing-mail = {
      cores     = 2
      memory    = 4
      disk_size = 30
      nat_enabled = false
      core_fraction = 20
      platform_id = "standard-v2"
    }
  }
}

variable "container_registry_id" {
  description = "ID Container Registry в Yandex Cloud"
  type        = string
  default     = ""
}

variable "container_image" {
  description = "Полный путь к образу контейнера (cr.yandex/<registry-id>/<repo-name>:<tag>)"
  type        = string
  default     = ""
}

variable "ycr_iam_token" {
  description = "IAM токен для доступа к Yandex Container Registry (будет сохранен в Lockbox)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_port" {
  description = "Порт приложения внутри контейнера"
  type        = number
  default     = 8080
}

variable "enable_container_deployment" {
  description = "Включить автоматическое развертывание контейнера"
  type        = bool
  default     = false
}

variable "enable_container_registry" {
  description = "Create Yandex Container Registry"
  type        = bool
  default     = false
}

variable "container_registry_name" {
  description = "Name of Container Registry"
  type        = string
  default     = "app-registry"
}

variable "existing_container_registry_id" {
  description = "ID of existing Container Registry (if empty, new registry will be created)"
  type        = string
  default     = ""
}
