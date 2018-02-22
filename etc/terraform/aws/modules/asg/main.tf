resource "aws_autoscaling_group" "terraform_ccc_asg_worker" {
  # availability_zones        = ["${var.availability_zones}"]
  vpc_zone_identifier       = ["${var.subnets}"]
  name_prefix               = "terraform-ccc-asg-worker-"
  max_size                  = "${var.max_size}"
  min_size                  = "${var.min_size}"
  health_check_grace_period = 1000
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.terraform_ccc_worker.name}"
  load_balancers            = ["${aws_elb.terraform_ccc_worker_elb.name}"]

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Name"
    value               = "terraform-ccc-worker"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "terraform_ccc_worker" {
  name_prefix   = "terraform-ccc-worker-lc-"
  image_id      = "${var.gpu == "1" ? lookup(var.amis-ubuntu, var.region) : lookup(var.amis, var.region)}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.terraform_ccc_server.id}", "${var.redis_security_group_id}"]
  user_data =  <<EOF
#!/bin/bash

if [ "${var.gpu}" == "1" ]
then
  echo 'Installing GPU drivers'
  sudo apt-get update
  sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
  sudo apt-get install -y gcc

  wget http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
  sudo dpkg -i cuda-repo-ubuntu1604_9.1.85-1_amd64.deb
  sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
  sudo apt-get update
  sudo apt-get install -y cuda

  echo 'PATH="/usr/local/cuda-9.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"' | sudo tee /etc/environment

  echo "LD_LIBRARY_PATH=/usr/local/cuda-9.1/lib64" | sudo tee -a /etc/environment

  # Reboot?

  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
  curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu16.04/amd64/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
  sudo apt-get update
  sudo apt-get install -y nvidia-docker2
  sudo pkill -SIGHUP dockerd

  #Test: docker run --runtime=nvidia --rm nvidia/cuda nvidia-smi
  #Apparently not needed
  #sudo reboot
fi
docker run --detach \
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
 -e GPU=${var.gpu} \
  dionjwa/cloud-compute-cannon:${var.server_version}

EOF

  lifecycle {
    create_before_destroy = true
  }

  key_name = "${var.key_name}"

  root_block_device = {
    volume_size = "30"
  }
}


resource "aws_security_group" "terraform_ccc_server" {
  description = "server/worker sg"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port        = 9000
    to_port          = 9000
    protocol         = "tcp"
    #Swap these two if you need to hit a specific machine
    # cidr_blocks      = ["0.0.0.0/0"]
    security_groups  = ["${aws_security_group.terraform_ccc_worker_elb.id}"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "terraform_ccc_worker_elb" {
  name               = "ccc-terraform-elb"
  security_groups    = ["${aws_security_group.terraform_ccc_worker_elb.id}", "${aws_security_group.terraform_ccc_server.id}"]
  subnets            = ["${var.subnets}"]

  listener {
    instance_port     = 9000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # listener {
  #   instance_port      = 9000
  #   instance_protocol  = "http"
  #   lb_port            = 443
  #   lb_protocol        = "https"
  #   ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  # }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    target              = "HTTP:9000/test"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "ccc-terraform-elb"
  }
}

resource "aws_security_group" "terraform_ccc_worker_elb" {
  description = "worker_elb sg"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
