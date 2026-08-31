variable "name" {
  type    = string
  default = null
}

variable "namespace" {
  type    = string
  default = null
}

variable "profile" {
  type    = string
  default = null
}

variable "region" {
  type    = string
  default = null
}

variable "allowed_cidrs" {
  type = list(string)
  # default = ["0.0.0.0/0"]
  default = []
}

variable "spot" {
  type    = bool
  default = true
}

variable "instance_type" {
  type    = string
  default = "t4g.nano"
}

variable "ttl_hours" {
  type    = number
  default = null
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "subnet_id" {
  type    = string
  default = null
}
