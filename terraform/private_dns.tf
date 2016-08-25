###############################
# Private (internal) DNS zone
###############################


resource "aws_route53_zone" "internal" {
  name = "${var.internal_dns_zone_name}"
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.vpc_name}"
    Owner = "${var.owner}"
  }
}
