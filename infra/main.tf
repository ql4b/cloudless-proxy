module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace = var.namespace
  name      = var.name
}

module "proxy" {
  # After the next release, switch to the registry source:
  # source  = "ql4b/ec2-proxy/aws"
  # version = "~> 2.5"
  source = "git@github.com:ql4b/terraform-aws-ec2-proxy.git?ref=feat/optional-vpc-subnet"

  context       = module.label.context
  allowed_cidrs = var.allowed_cidrs
  instance_type = var.instance_type
  ttl_hours     = var.ttl_hours
  spot          = var.spot

  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
}
