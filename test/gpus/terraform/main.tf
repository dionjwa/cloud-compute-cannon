# Declare the data source
data "aws_availability_zones" "available" {}

# The core DCC module
module "asg" {
  source                                   = "../../../etc/terraform/aws/modules/asg"
  api-security-group-ids                   = "" # There's nothing else in the stack using this
  bastion-security-group-id                = "${aws_security_group.bastion.id}"
  dcc-docker-image                         = "dionjwa/docker-cloud-compute:${local.dcc_version}"
  env-prefix                               = "${local.env}-"
  fluent_host                              = "${module.elk.private_ip}"
  instance_type_cpu                        = "${var.instance_type_cpu}"
  instance_type_gpu                        = "${var.instance_type_gpu}"
  instance_type_server                     = "${var.instance_type_server}"
  key_name                                 = "${local.key_name}"
  redis_host                               = "${module.redis.hostname}"
  redis_security_group_id                  = "${module.redis.security_group_id}"
  region                                   = "${local.region}"
  s3_access_key                            = "${var.s3_access_key}"
  s3_bucket                                = "${local.env}-dcc-jobs"
  s3_region                                = "${local.region}"
  s3_secret_key                            = "${var.s3_secret_key}"
  servers_max                              = "${var.servers_max}"
  servers_max                              = "${var.servers_min}"
  subnets                                  = ["${concat("${module.vpc.private_subnets}")}"]
  vpc_id                                   = "${module.vpc.vpc_id}"
  workers_cpu_empty_queue_scale_down_delay = "10"
  workers_cpu_max                          = "${var.workers_cpu_max}"
  workers_cpu_min                          = "${var.workers_cpu_min}"
  workers_gpu_empty_queue_scale_down_delay = "25"
  workers_gpu_max                          = "${var.workers_gpu_max}"
  workers_gpu_min                          = "${var.workers_gpu_min}"
}

# The minimal stack components the core DCC module needs.
#  - redis
#  - s3 bucket
#  - bastion instance (in bastion.tf)
#  - minimal ELK stack for viewing logs
#  - VPC to hold it all together

#Redis
module "redis" {
  source        = "../../../etc/terraform/aws/modules/redis/minimal"
  name-prefix   = "${local.env}-"
  region        = "${local.region}"
  vpc_id        = "${module.vpc.vpc_id}"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${local.key_name}"
  instance_type = "t2.micro"
}

#S3 bucket
module "s3" {
  source      = "../../../etc/terraform/aws/modules/s3_bucket"
  access_key  = "${var.s3_access_key}"
  secret_key  = "${var.s3_secret_key}"
  region      = "${local.region}"
  bucket_name = "${local.env}-dcc-jobs"
}

#ELK stack (logging)
module "elk" {
  source        = "../../../etc/terraform/aws/modules/elasticsearch-fluent-kibana-minimal"
  name-prefix   = "${local.env}-"
  region        = "${local.region}"
  vpc_id        = "${module.vpc.vpc_id}"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${local.key_name}"
  instance_type = "t2.micro"
}

# VPC
module "vpc" {
  source                             = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=master"

  name                               = "${local.env}-dcc-vpc"
  cidr                               = "10.0.0.0/16"

  #TODO: parameterize this for the multi-zone params
  azs                                = ["${data.aws_availability_zones.available.names[0]}"]

  create_database_subnet_group       = false

  private_subnets                    = ["10.0.1.0/24"]
  public_subnets                     = ["10.0.101.0/24"]
  enable_nat_gateway                 = true
  enable_vpn_gateway                 = true
  single_nat_gateway                 = true
  #Experimenting with this
  propagate_private_route_tables_vgw = true
  default_vpc_enable_dns_hostnames   = true
  # default_vpc_enable_dns_support     = true

  tags = {
    Terraform = "true"
    Environment = "${local.env}"
    System = "dcc"
  }
}
