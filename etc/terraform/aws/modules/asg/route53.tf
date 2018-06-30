resource "aws_route53_record" "terraform_dcc_worker_dns_alias" {
  count   = "${var.route53_record_zone_id != "" && var.route53_record_name != "" ? 1 : 0}"
  zone_id = "${var.route53_record_zone_id}"
  name    = "${var.route53_record_name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.dcc_elb.dns_name}"
    zone_id                = "${aws_elb.dcc_elb.zone_id}"
    evaluate_target_health = false
  }
}
