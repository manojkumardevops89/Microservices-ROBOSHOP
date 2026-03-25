data "aws_route53_zone" "main" {
  name = "manojdevops897.shop"
}

resource "aws_route53_record" "roboshop" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "roboshop.manojdevops897.shop"
  type    = "CNAME"
  ttl     = 60

  records = [var.alb_dns_name]
}
