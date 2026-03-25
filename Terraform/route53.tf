# You must already have a hosted zone in Route53
# Replace "yourdomain.com" with your actual domain
data "aws_route53_zone" "main" {
  name = "manojdevops897.shop"
}

# ---- Record pointing to AZ-1a (weight 50) ----
resource "aws_route53_record" "roboshop_1a" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "roboshop.manojdevops897.shop"
  type    = "CNAME"

  weighted_routing_policy {
    weight = 50
  }

  set_identifier = "roboshop-1a"
  ttl            = 60
  records        = ["your-alb-1a-dns-name.us-east-1.elb.amazonaws.com"]
}

# ---- Record pointing to AZ-1b (weight 50) ----
resource "aws_route53_record" "roboshop_1b" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "roboshop.manojdevops897.shop"
  type    = "CNAME"

  weighted_routing_policy {
    weight = 50
  }

  set_identifier = "roboshop-1b"
  ttl            = 60
  records        = ["your-alb-1b-dns-name.us-east-1.elb.amazonaws.com"]
}
