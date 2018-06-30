resource "aws_autoscaling_group" "dcc_asg_worker_gpu" {
  vpc_zone_identifier       = ["${split(",", var.subnets)}"]
  name_prefix               = "${var.env_prefix}dcc-asg-worker-gpu-"
  max_size                  = "${var.workers_gpu_max}"
  min_size                  = "${var.workers_gpu_min}"
  health_check_grace_period = 1000
  health_check_type         = "ELB"
  desired_capacity          = "${var.workers_gpu_min}"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.dcc_worker_gpu.name}"
  # Only use a load balancer if this ASG is fronting requests
  load_balancers            = ["${split(",", local.server_suffix == "gpu" ? "${aws_elb.dcc_elb.name}" : "")}"]

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Name"
    value               = "${var.env_prefix}dcc-worker-gpu"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "dcc_worker_gpu" {
  name_prefix          = "${var.env_prefix}dcc-worker-gpu-lc-"
  image_id             = "${lookup(var.amis-gpu, var.region)}"
  instance_type        = "${var.instance_type_gpu}"
  security_groups      = ["${aws_security_group.dcc_server.id}", "${var.redis_security_group_id}"]
  user_data =  <<EOF
#!/bin/bash
sudo docker run --detach \
 --restart always \
 --publish "9000:9000" \
 -v "/var/run/docker.sock:/var/run/docker.sock" \
 -e REDIS_HOST=${var.redis_host} \
 -e FLUENT_HOST=${var.fluent_host} \
 -e FLUENT_PORT=${var.fluent_port} \
 -e LOG_LEVEL=${var.log_level} \
 -e CLOUD_PROVIDER_TYPE=aws \
 -e AWS_S3_KEYID=${var.s3_access_key} \
 -e AWS_S3_KEY=${var.s3_secret_key} \
 -e AWS_S3_BUCKET=${var.s3_bucket} \
 -e AWS_S3_REGION=${var.s3_region} \
 -e KIBANA_URL=${var.kibana_url} \
 -e GPUS=${var.workers_gpu_max >= "1" ? 1 : 0} \
  ${var.dcc_docker_image}
EOF

  lifecycle {
    create_before_destroy = true
  }

  key_name = "${var.key_name}"

  root_block_device = {
    volume_size = "80"
  }
}
