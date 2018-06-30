resource "aws_instance" "dcc_redis" {
  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.instance_type}"
  subnet_id = "${var.subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.dcc_redis.id}"]
  monitoring  = true

  # Examine /var/log/cloud-init-output.log for errors
   user_data =  <<EOF
#!/bin/bash
docker run --restart=always -p 6379:6379 --detach redis:3.2.0-alpine
EOF

  key_name = "${var.key_name}"

  tags {
    Name = "${var.name-prefix}dcc-redis-micro"
  }
}

resource "aws_security_group" "dcc_redis" {
  description = "${var.name-prefix} Restrict redis access to servers and workers"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port         = 6379
    to_port           = 6379
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 6379
    to_port           = 6379
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  # Terraform removes this default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
