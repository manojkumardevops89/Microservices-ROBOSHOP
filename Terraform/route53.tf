data "aws_route53_zone" "main" {
  name = "manojdevops897.shop"
}

resource "aws_route53_record" "roboshop" {
  count   = var.alb_dns_name == "" ? 0 : 1   # ✅ KEY FIX

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "roboshop.manojdevops897.shop"
  type    = "CNAME"
  ttl     = 60

  records = [var.alb_dns_name]
}
