# ECS optimized AWS linux, with docker installed.
# The stack logic is all in docker images, so no other pieces are needed.
# http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
variable "amis" {
  type = "map"
  default = {
    us-east-2 = "ami-b0527dd5"
    us-east-1 = "ami-20ff515a"
    us-west-2 = "ami-3702ca4f"
    us-west-1 = "ami-b388b4d3"
    eu-west-1 = "ami-d65dfbaf"
    eu-west-2 = "ami-ee7d618a"
    eu-central-1 = "ami-ebfb7e84"
    ap-northeast-2 = "ami-70d0741e"
    ap-northeast-1 = "ami-95903df3"
    ap-southeast-2 = "ami-e3b75981"
    ap-southeast-1 = "ami-c8c98bab"
    ca-central-1 = "ami-fc5fe798"
  }
}

#For GPU instances
variable "amis-gpu" {
  type = "map"
  default = {
    us-east-2 = "ami-4f80b52a"
    us-east-1 = "ami-0b383171"
    us-west-2 = "ami-c62eaabe"
    us-west-1 = "ami-9cb2bdfc"
    eu-west-1 = "ami-c1167eb8"
    eu-west-2 = "ami-e0bc5987"
    eu-west-3 = "ami-6bad1b16"
    eu-central-1 = "ami-714f2b1e"
    ap-northeast-2 = "ami-35a3015b"
    ap-northeast-1 = "ami-adceb9cb"
    ap-southeast-2 = "ami-e1c43f83"
    ap-southeast-1 = "ami-a55c1dd9"
    ca-central-1 = "ami-c7a622a3"
  }
}
