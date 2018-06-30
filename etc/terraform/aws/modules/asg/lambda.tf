resource "aws_iam_role" "dcc_lambda_role" {
  name = "${var.env_prefix}_dcc_lambda_role"
  path = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["lambda.amazonaws.com"]
      },
      "Action": ["sts:AssumeRole"]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "dcc_lambda_iam_scale_policy" {
  name_prefix = "${var.env_prefix}_dcc_lambda_iam_scale_policy"
  path = "/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["logs:*"],
      "Resource": ["arn:aws:logs:*:*:*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "autoscaling:*"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "dcc_lambda_policy_attachment" {
  policy_arn = "${aws_iam_policy.dcc_lambda_iam_scale_policy.arn}"
  role = "${aws_iam_role.dcc_lambda_role.name}"
}

resource "aws_cloudwatch_event_rule" "dcc_lambda_scale_timer_rule" {
  name        = "${var.env_prefix}dcc_lambda-rule-scale-timer"
  description = "Fire this event every minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "dcc_lambda_scale_timer_target" {
    rule = "${aws_cloudwatch_event_rule.dcc_lambda_scale_timer_rule.name}"
    target_id = "${var.env_prefix}dcc_lambda_scale"
    arn = "${aws_lambda_function.dcc_lambda_scale.arn}"
}

resource "aws_lambda_permission" "dcc_allow_cloudwatch_to_call_lambda_scale" {
  statement_id   = "PermissionInvokeLambdaScale"
  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.dcc_lambda_scale.function_name}"
  principal      = "events.amazonaws.com"
  source_arn     = "${aws_cloudwatch_event_rule.dcc_lambda_scale_timer_rule.arn}"
}

resource "aws_lambda_function" "dcc_lambda_scale" {
  filename         = "${path.module}/lambda.zip"
  function_name    = "${var.env_prefix}_dcc_lambda_scale"
  role             = "${aws_iam_role.dcc_lambda_role.arn}"
  handler          = "index.handlerScale"
  runtime          = "nodejs6.10"
  timeout          = 60
  vpc_config {
    subnet_ids = ["${split(",", var.subnets)}"]
    security_group_ids = ["${var.redis_security_group_id}", "${aws_security_group.dcc_server.id}"]
  }

  environment {
    variables {
      REDIS_HOST                               = "${var.redis_host}"
      ASG_NAME                                 = "${aws_autoscaling_group.dcc_asg_worker_cpu.name}"
      ASG_GPU_NAME                             = "${aws_autoscaling_group.dcc_asg_worker_gpu.name}"
      ASG_NAME_SERVER                          = "${aws_autoscaling_group.dcc_asg_server.name}"
      MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_CPU = "${var.workers_cpu_empty_queue_scale_down_delay}"
      MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_GPU = "${var.workers_gpu_empty_queue_scale_down_delay}"
    }
  }

  source_code_hash = "${base64sha256(file("${path.module}/lambda.zip"))}"
}