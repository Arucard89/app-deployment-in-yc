variable "folder_id" {
  description = "Folder ID в Yandex Cloud"
  type        = string
}

variable "default_zone" {
  description = "Зона доступности по умолчанию"
  type        = string
  default     = "ru-central1-a"
}

variable "network_id" {
  description = "ID VPC сети"
  type        = string
}

variable "subnet_id" {
  description = "ID подсети"
  type        = string
}

variable "security_group_id" {
  description = "ID группы безопасности"
  type        = string
}

variable "postgresql_ip" {
  description = "IP адрес PostgreSQL сервера"
  type        = string
  default     = ""
} 