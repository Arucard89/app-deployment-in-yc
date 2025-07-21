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
