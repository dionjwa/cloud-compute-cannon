resource "aws_autoscaling_group" "dcc_asg_server" {
  vpc_zone_identifier       = ["${split(",", var.subnets)}"]
  name_prefix               = "${var.env_prefix}dcc-asg-server-"
  max_size                  = "${var.servers_max}"
  min_size                  = "${var.servers_min}"
  health_check_grace_period = 1000
  health_check_type         = "ELB"
  desired_capacity          = "${var.servers_min}"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.dcc_server.name}"
  load_balancers            = ["${split(",", local.server_suffix == "server" ? "${aws_elb.dcc_elb.name}" : "")}"]

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Name"
    value               = "${var.env_prefix}dcc-asg-server"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "dcc_server" {
  count                = "${var.servers_max >= "1" ? 1 : 0}"
  name_prefix          = "${var.env_prefix}dcc-server-lc-"
  image_id             = "${lookup(var.amis, var.region)}"
  instance_type        = "${var.instance_type_server}"
  security_groups      = ["${aws_security_group.dcc_server.id}", "${var.redis_security_group_id}"]
  user_data =  <<EOF
#!/bin/bash

docker run --detach \
 --restart always \
 --publish "9000:9000" \
 -v "/var/run/docker.sock:/var/run/docker.sock" \
 -e REDIS_HOST=${var.redis_host } \
 -e FLUENT_HOST=${var.fluent_host} \
 -e FLUENT_PORT=${var.fluent_port} \
 -e LOG_LEVEL=${var.log_level} \
 -e CLOUD_PROVIDER_TYPE=aws \
 -e AWS_S3_KEYID=${var.s3_access_key} \
 -e AWS_S3_KEY=${var.s3_secret_key} \
 -e AWS_S3_BUCKET=${var.s3_bucket} \
 -e AWS_S3_REGION=${var.s3_region} \
 -e KIBANA_URL=${var.kibana_url} \
 -e GPUS=0 \
 -e DISABLE_WORKER=true \
  ${var.dcc_docker_image}

EOF

  lifecycle {
    create_before_destroy = true
  }

  key_name = "${var.key_name}"

  root_block_device = {
    volume_size = "30"
  }
}
