resource "aws_elb" "dcc_elb" {
  name               = "${var.env_prefix}dcc-elb"
  security_groups    = ["${aws_security_group.dcc_elb_sg.id}", "${aws_security_group.dcc_server.id}", "${var.bastion_security_group}", "${var.api_security_group}"]
  subnets            = ["${split(",", var.subnets)}"]

  listener {
    instance_port     = 9000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    target              = "HTTP:9000/healthcheck"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = true

  tags {
    Name = "dcc-elb"
  }
}
