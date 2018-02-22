variable "access_key" {}
variable "secret_key" {}
variable "public_key" {}
variable "region" {}
variable "server_version" {}

#CCC stack in AWS
module "stack_cheapest_scalable" {
  # source      = "git::https://github.com/dionjwa/cloud-compute-cannon//etc/terraform/aws/modules/stack_cheapest_scalable?ref=master"
  source      = "../../modules/stack_cheapest_scalable"
  access_key  = "${var.access_key}"
  secret_key  = "${var.secret_key}"
  region      = "${var.region}"
  public_key  = "${var.public_key}"
  gpu         = "1"
  worker_type = "p2.xlarge"
  server_version     = "${var.server_version}"
}

output "kibana" {
  value = "http://${module.stack_cheapest_scalable.kibana}:5601"
}

output "url" {
  value = "http://${module.stack_cheapest_scalable.url}"
}