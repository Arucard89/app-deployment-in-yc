yc iam access-key create \
 --service-account-id <service-account-id> \
 --output key > key.json
export AWS_ACCESS_KEY_ID=$(jq -r .access_key_id key.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r .secret key.json)
terraform init -backend-config="access_key=$AWS_ACCESS_KEY_ID" -backend-config="secret_key=$AWS_SECRET_ACCESS_KEY"

или вместо tf использовать только yc

yc iam access-key create \
 --service-account-id <service-account-id> \
 --output key > key.json

yc storage bucket create \
 --name kamerton-app-yc-tf-state \
 --folder-id b1gbp726g1kmkcoa8iai \
 --profile kamerton-terraform-sa

yc storage bucket update \
 --name kamerton-app-yc-tf-state \
 --versioning versioning-enabled \
 --profile kamerton-terraform-sa
