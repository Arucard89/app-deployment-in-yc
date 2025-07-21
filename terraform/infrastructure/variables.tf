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
    nat_enabled = bool
  }))
  default = {
    frontend = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = true
    }
    api = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = false
    }
    main = {
      cores     = 2
      memory    = 4
      disk_size = 20
      nat_enabled = false
    }
    billing-mail = {
      cores     = 2
      memory    = 4
      disk_size = 30
      nat_enabled = false
    }
  }
}
