output "hostname" {
  value = "${aws_instance.dcc_redis.private_ip}"
}

output "security_group_id" {
  value = "${aws_security_group.dcc_redis.id}"
}

