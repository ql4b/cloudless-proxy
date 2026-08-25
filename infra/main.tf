module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace = var.namespace
  name      = var.name
}

module "proxy" {
  source  = "ql4b/ec2-proxy/aws"
  version = "~> 2.0"

  context       = module.label.context
  allowed_cidrs = var.allowed_cidrs
  instance_type = var.instance_type
  ttl_hours     = var.ttl_hours
  spot          = var.spot
}
