# Deployment Variables - ${deployment_vars.timestamp}
# Generated automatically by Terraform

TIMESTAMP=${deployment_vars.timestamp}
NETWORK_ID=${deployment_vars.network_id}
SUBNET_ID=${deployment_vars.subnet_id}
SECURITY_GROUP_ID=${deployment_vars.security_group_id}
NAT_GATEWAY_ID=${deployment_vars.nat_gateway_id}
ROUTE_TABLE_ID=${deployment_vars.route_table_id}

# Microservices IPs
%{ for service, ip in deployment_vars.microservices_ips ~}
${upper(service)}_IP=${ip}
%{ endfor ~} 