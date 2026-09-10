output "asg_name" {
  description = "Name of the ASG managing the proxy. Scale it 0<->1 to stop/start the proxy: aws autoscaling set-desired-capacity --auto-scaling-group-name <name> --desired-capacity <0|1>"
  value       = module.proxy.asg_name
}

output "launch_template_id" {
  value = module.proxy.launch_template_id
}

output "instance_type" {
  value = module.proxy.instance_type
}

output "region" {
  value = module.proxy.region
}

output "ttl_hours" {
  value = module.proxy.ttl_hours
}

# The running instance is ASG-managed and dynamic, so its IP/URL are not
# Terraform outputs. Use `./bin/proxy url` (or `./bin/proxy status`), which
# resolves the live instance from EC2 by the proxy:managed-by tag.
