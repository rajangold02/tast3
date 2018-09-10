output "alb_address" {
	value = "${aws_alb.main.dns_name}"
}
output "asg_name" {
	value = "${aws_autoscaling_group.auto_scaling.name}"
}
output "instance_sg_id" {
	value = "${aws_security_group.instance.id}"
}
output "Launch_configuration" {
	value = "${aws_launch_configuration.launch_config.id}"
}



