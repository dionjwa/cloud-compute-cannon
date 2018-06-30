resource "aws_security_group" "dcc_elb_sg" {
  description = "${var.env_prefix} dcc elb sg"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${var.bastion_security_group}", "${var.api_security_group}"]
    self           = true
  }
}

resource "aws_security_group" "dcc_server" {
  description = "${var.env_prefix} dcc server/worker sg"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port        = 9000
    to_port          = 9000
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.dcc_elb_sg.id}", "${var.bastion_security_group}"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = ["${var.bastion_security_group}"]
  }

  # Terraform removes this default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
