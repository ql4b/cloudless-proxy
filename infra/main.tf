module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace = var.namespace
  name      = var.name
}

module "proxy" {
  # Tracking the module's feature branch (v3 ASG redesign) for validation.
  # Switch to the registry source (ql4b/ec2-proxy/aws, version ~> 3.0) once released.
  source = "github.com/ql4b/terraform-aws-ec2-proxy?ref=feat/autoscaling-group"

  context       = module.label.context
  allowed_cidrs = var.allowed_cidrs
  instance_type = var.instance_type
  ttl_hours     = var.ttl_hours

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
}
