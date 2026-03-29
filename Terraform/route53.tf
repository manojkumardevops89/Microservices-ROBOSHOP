data "aws_route53_zone" "main" {
  name = "manojdevops897.shop"
}

resource "aws_route53_record" "roboshop" {
  count   = var.alb_dns_name == "" ? 0 : 1
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "roboshop.manojdevops897.shop"
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
