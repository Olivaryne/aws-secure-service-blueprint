resource "aws_vpc_endpoint" "interface" {
  for_each = var.create_vpc_endpoints ? local.interface_endpoint_services : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for subnet in aws_subnet.app : subnet.id]
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = {
    Name = "${var.name}-${replace(each.key, ".", "-")}-vpce"
  }
}

resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.app : route_table.id]

  tags = {
    Name = "${var.name}-s3-vpce"
  }
}
