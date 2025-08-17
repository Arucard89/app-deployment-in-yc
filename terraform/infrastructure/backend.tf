# Remote backend for the microservices stack.
# State will be stored in Yandex Object Storage under the key `microservices.tfstate`.
terraform {
  backend "s3" {
    endpoint = "https://storage.yandexcloud.net"

    bucket = "kamerton-app-yc-tf-state"
    region = "ru-central1"
    key    = "microservices.tfstate"
    access_key = "YCAJEOf8asUWfy58ihd7EqTCF"

    # Disable AWS-specific validations that are not relevant for Yandex Object Storage
    skip_region_validation      = true
    skip_metadata_api_check      = true
    skip_credentials_validation = true
  }
}
