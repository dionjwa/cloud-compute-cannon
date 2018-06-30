output "proxy-tunnel-internal-worker-to-localhost" {
  # You can hit the remote app server at localhost:9090
  value = "ssh -N -L 9090:localhost:9000 -o \"ProxyCommand ssh -L 9000:localhost:9000 -i ~/.ssh/${local.key_name}.pem ec2-user@${aws_instance.bastion.public_ip} -W %h:%p\" -i ~/.ssh/${local.key_name}.pem ec2-user@`make get-aws-server-ip`"
}

output "proxy-tunnel-kibana-to-localhost" {
  # You can hit the remote kibana server at localhost:5601
  value = "ssh -N -L 5601:localhost:5601 -o \"ProxyCommand ssh -L 5601:localhost:5601 -i ~/.ssh/${local.key_name}.pem ec2-user@${aws_instance.bastion.public_ip} -W %h:%p\" -i ~/.ssh/${local.key_name}.pem ec2-user@${module.elk.private_ip}"
}

output "ssh-instance" {
  # SSH into any of the instances via the bastion
  value = "ssh -o \"ProxyCommand ssh -i ~/.ssh/${local.key_name}.pem ec2-user@${aws_instance.bastion.public_ip} -W %h:%p\" -i ~/.ssh/${local.key_name}.pem ec2-user@<PRIVATE_IP>"
}

output "bastion-ip" {
  value = "${aws_instance.bastion.public_ip}"
}

output "elk-private_ip" {
  value = "${module.elk.private_ip}"
}

output "aws_availability_zones" {
  value = "${data.aws_availability_zones.available.names}"
}

output "region" {
  value = "${local.region}"
}

data "aws_region" "current" {}

output "aws_region" {
  value = "${data.aws_region.current.name}"
}

output "asg-redis_security_group_id" {
  value = "${module.asg.redis_security_group_id}"
}

output "aws_security_group-dcc_server-id" {
  value = "${module.asg.aws_security_group-dcc_server-id}"
}

output "asg-image" {
  value = "${module.asg.image}"
}

output "asg-subnets" {
  value = "${module.asg.subnets}"
}

output "asg-cpu" {
  value = "${module.asg.asg-cpu}"
}

output "asg-gpu" {
  value = "${module.asg.asg-gpu}"
}
