# A security group that will be allowed access to the ELB
# Not useful if internal=false, since the API will be public.
variable "api_security_group" { default = "" }

# Bastion security group id
# If given, allows bastion nodes to hit relevant servers
variable "bastion_security_group" { default = "" }

variable "env_prefix" {
  default = "env-"
}

variable "dcc_docker_image" {
  default = "dionjwa/docker-cloud-compute:0.4.4-"
}

variable "instance_type_cpu" {
  default = "t2.small"
}

variable "instance_type_gpu" {
   default = "p2.xlarge"
}

variable "instance_type_server" {
  default = "t2.micro"
}

variable "route53_record_zone_id" {
  default = ""
}

variable "route53_record_name" {
  default = ""
}

variable "workers_cpu_max" {
  default = 1
}

variable "workers_cpu_min" {
  default = 1
}

# When the queue is empty, wait this many minutes
# before scaling down
variable "workers_cpu_empty_queue_scale_down_delay" {
  default = 20
}

variable "workers_gpu_max" {
  default = 0
}

variable "workers_gpu_min" {
  default = 0
}

# When the queue is empty, wait this many minutes
# before scaling down
variable "workers_gpu_empty_queue_scale_down_delay" {
  default = 30
}

# If this is >= 1 then a separate pool of servers and
# workers will be created. This allows much cheaper
# servers to be constantly available without paying the
# cost of expensive compute instances.
variable "servers_max" {
  default = 1
}

variable "servers_min" {
  default = 1
}

variable "s3_access_key" {}
variable "s3_secret_key" {}
variable "s3_region" {}
variable "s3_bucket" {
  default = "docker-cloud-compute-data"
}

variable "key_name" {}

#Comma separated subnet ids
variable "subnets" {}

variable "region" {
  description = "AWS region"
}

variable "vpc_id" {}

variable "redis_host" {}

variable "redis_security_group_id" {}

variable "fluent_host" {
  default = ""
}

variable "kibana_url" {
  default = ""
}

variable "fluent_port" {
  default = 24224
}

variable "log_level" {
  default = "debug"
}
