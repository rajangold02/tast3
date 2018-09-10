variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "az_count"{
default = "1"
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
 default = "30.0.0.0/16"
}
variable "destinationcidrblock" {
        default = "0.0.0.0/0"
}
variable "mappublicip" {
        default = true
}
variable "keypair_name" {
 default = "smartcity"
}
variable "instance_type" {
 default = "t2.micro"
}
variable "asg_config" {
 default = "1"
}
variable "ecs_service_role_name" {
default = "ecsroleservice"
}