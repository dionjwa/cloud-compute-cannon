output "api_security_group" {
  value = "${var.api_security_group}"
}

output "elb_zone_id" {
  value = "${aws_elb.dcc_elb.zone_id}"
}

output "server_fqdn" {
  value = "${element(concat(aws_route53_record.terraform_dcc_worker_dns_alias.*.fqdn, list("")), 0)}"
}

output "elb_dns_name" {
  value = "${aws_elb.dcc_elb.dns_name}"
}

# If you cannot pass in a security group to be
# added to the ELB then you can add your own instances
# to this security group
output "elb_security_group" {
  value = "${aws_security_group.dcc_elb_sg.id}"
}

output "redis_host" {
  value = "${var.redis_host}"
}

output "redis_security_group_id" {
  value = "${var.redis_security_group_id}"
}

output "dcc_instance_security_group_id" {
  value = "${aws_security_group.dcc_server.id}"
}

output "image" {
  value = "${var.dcc_docker_image}"
}

output "asg_cpu" {
  value = "${aws_autoscaling_group.dcc_asg_worker_cpu.name}"
}

output "asg_gpu" {
  value = "${aws_autoscaling_group.dcc_asg_worker_gpu.name}"
}

output "asg_server" {
  value = "${aws_autoscaling_group.dcc_asg_server.name}"
}

output "subnets" {
  value = "${var.subnets}"
}

output "vpc_id" {
  value = "${var.vpc_id}"
}
