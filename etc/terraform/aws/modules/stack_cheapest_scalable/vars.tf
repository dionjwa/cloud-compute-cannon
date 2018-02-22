variable "access_key" {}
variable "secret_key" {}
variable "public_key" {}
variable "region" {}

# S3 required vars
variable "bucket_name" {
  default = "cloud-compute-job-data-"
}

variable "worker_type" {
  default = "t2.micro"
}

# Is this mini stack GPU instances?
variable "gpu" {
  default = "0"
}

# On need this when developing locally
variable "server_version" {}