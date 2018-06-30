resource "aws_instance" "bastion" {
  ami                         = "${lookup(var.amis-bastion, local.region)}"
  associate_public_ip_address = true
  instance_type               = "t2.nano"
  key_name                    = "${local.key_name}"
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}", "${module.redis.security_group_id}"]

  tags {
    Name = "${local.env}-dcc-bastion"
  }
}

# Use a stock Amazon linux image.
variable "amis-bastion" {
  type = "map"
  default = {
    us-east-1 = "ami-2d387344" # https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Images:visibility=public-images;search=aws%20linux;sort=name
    us-west-2 = "ami-d8233da1" # https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#Images:visibility=public-images;search=aws%20linux;sort=name
  }
}

# Only SSH in, but can agress anything
resource "aws_security_group" "bastion" {
  description = "${local.env} dcc bastion sg"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Terraform removes this default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
