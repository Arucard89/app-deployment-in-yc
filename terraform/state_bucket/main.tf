# Terraform configuration to create a dedicated bucket for storing Terraform state
# This configuration can be applied ONCE with a local backend to bootstrap the bucket.
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.72.0"
    }
  }
  required_version = ">= 1.3"
}

# Use credentials from the current yc profile.
# The specific zone value is not important for Object Storage, but it must be set.
provider "yandex" {
  zone = "ru-central1-a"
}

# Object Storage bucket that will keep all Terraform state files.
# Versioning is enabled to preserve full history of state changes.
resource "yandex_storage_bucket" "tf_state_bucket" {
  bucket = "kamerton-app-yc-tf-state"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    purpose = "terraform-state"
  }
}
