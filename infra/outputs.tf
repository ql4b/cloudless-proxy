output "proxy_url" {
  sensitive = true
  value     = module.proxy.proxy_url
}

output "public_ip" {
  value = module.proxy.public_ip
}

output "instance_id" {
  value = module.proxy.instance_id
}

output "instance_type" {
  value = module.proxy.instance_type
}

output "is_spot" {
  value = module.proxy.is_spot
}

output "region" {
  value = module.proxy.region
}

output "ttl_hours" {
  value = module.proxy.ttl_hours
}
