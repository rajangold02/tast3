variable "access_key" {}
variable "secret_key" {}
variable "region" {}

variable "az_count" {
  default = "2"
}

variable "instanceTenancy" {
  default = "default"
}

variable "dnssupport" {
  default = true
}

variable "dnshostnames" {
  default = true
}

variable "vpccidrblock" {
  description = "Please give VPC cidr block range"
}

variable "destinationcidrblock" {
  default = "0.0.0.0/0"
}

variable "mappublicip" {
  default = true
}

variable "keypair_name" {
  description = "Key to access the server"
  default     = "smartcity"
}

variable "instance_type" {
  description = "Instance Size"
  default     = "t2.micro"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "2"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}

variable "ecs_service_role_name" {
  default = "ecsroleservice"
}
