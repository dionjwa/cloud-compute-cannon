output "private_ip" {
  value = "${aws_instance.dcc_elasticsearch_stack_mini.private_ip}"
}
