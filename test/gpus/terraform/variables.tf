variable "s3_access_key" {}
variable "s3_secret_key" {}
variable "instance_type_server" {
  default = "t2.micro"
}
variable "instance_type_cpu" {
   default = "t2.small"
}
variable "instance_type_gpu" {
   default = "p2.xlarge"
}
variable "servers_max" {
  default = 1
}
variable "servers_min" {
  default = 1
}
variable "workers_cpu_max" {
  default = 1
}
variable "workers_cpu_min" {
  default = 0
}
variable "workers_gpu_max" {
  default = 1
}
variable "workers_gpu_min" {
  default = 0
}
