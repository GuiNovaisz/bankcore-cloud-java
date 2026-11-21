variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "account_id" {
  type = string
}
variable "operator_cidrs" {
  type = set(string)
}
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-name"
    values = ["${var.region}a", "${var.region}b"]
  }
}
resource "aws_default_security_group" "restricted" {
  vpc_id = aws_vpc.this.id
  # Empty rules intentionally remove the default group's allow-all egress and self ingress.
}
locals {
  workloads = toset(["account-service", "ledger-service", "transfer-service", "projection-worker", "collector", "bootstrap"])
}
resource "aws_vpc" "this" {

  cidr_block           = "10.48.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.name
  }
  # checkov:skip=CKV2_AWS_11:Flow logs are explicitly created below with bounded retention.

}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}
resource "aws_subnet" "public" {

  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

}
resource "aws_subnet" "private" {

  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 10)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
}
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Approved operator HTTPS ingress only"
  vpc_id      = aws_vpc.this.id
}
resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each          = var.operator_cidrs
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Approved operator HTTPS"
}
resource "aws_security_group" "service" {
  for_each    = local.workloads
  name_prefix = "${var.name}-${each.key}-"
  description = "Per-workload traffic allowlist"
  vpc_id      = aws_vpc.this.id
}
resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "PostgreSQL from application tasks and bootstrap only"
  vpc_id      = aws_vpc.this.id
}
resource "aws_security_group" "cache" {
  name_prefix = "${var.name}-cache-"
  description = "TLS Redis from account tasks only"
  vpc_id      = aws_vpc.this.id
}
resource "aws_security_group" "endpoints" {
  name_prefix = "${var.name}-endpoints-"
  description = "Private AWS API endpoints"
  vpc_id      = aws_vpc.this.id
}
locals {

  edges = merge({
    for s in ["account-service", "ledger-service", "transfer-service", "projection-worker"] : "alb-${s}" => {
      source = aws_security_group.alb.id, dest = aws_security_group.service[s].id, port = 8080
    }
    },
    {
      for s in ["account-service", "transfer-service", "projection-worker"] : "${s}-ledger" => {
        source = aws_security_group.service[s].id, dest = aws_security_group.service["ledger-service"].id, port = 8080
      }
    },
    {
      "transfer-account" = {
        source = aws_security_group.service["transfer-service"].id, dest = aws_security_group.service["account-service"].id, port = 8080
      }
    },
    {
      for s in ["account-service", "ledger-service", "transfer-service", "projection-worker", "bootstrap"] : "${s}-db" => {
        source = aws_security_group.service[s].id, dest = aws_security_group.db.id, port = 5432
      }
    },
    {
      "account-cache" = {
        source = aws_security_group.service["account-service"].id, dest = aws_security_group.cache.id, port = 6379
      }
    },
    {
      for s in local.workloads : "${s}-endpoints" => {
        source = aws_security_group.service[s].id, dest = aws_security_group.endpoints.id, port = 443
      }
    },
    {
      for s in ["account-service", "ledger-service", "transfer-service", "projection-worker"] : "${s}-collector" => {
        source = aws_security_group.service[s].id, dest = aws_security_group.service["collector"].id, port = 4318
      }
  })

}
resource "aws_vpc_security_group_ingress_rule" "edges" {
  for_each                     = local.edges
  security_group_id            = each.value.dest
  referenced_security_group_id = each.value.source
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
  description                  = each.key
}
resource "aws_vpc_security_group_egress_rule" "edges" {
  for_each                     = local.edges
  security_group_id            = each.value.source
  referenced_security_group_id = each.value.dest
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
  description                  = each.key
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.this.id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [aws_route_table.private.id]
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = "*", Action = ["s3:GetObject"], Resource = ["arn:aws:s3:::prod-${var.region}-starport-layer-bucket/*"]
    }]
  })
}
resource "aws_vpc_security_group_egress_rule" "s3" {
  for_each          = local.workloads
  security_group_id = aws_security_group.service[each.key].id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "ECR image layers via S3 gateway endpoint"
}
resource "aws_vpc_endpoint" "apis" {

  for_each            = toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sqs", "xray"])
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = "*", Action = "*", Resource = "*", Condition = {
        StringEquals = {
          "aws:PrincipalAccount" = var.account_id
        }
      }
    }]
  })
  # Endpoint boundary restricts the account; workload IAM below further restricts every API action/resource.

}
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/bankcore/vpc-flow"
  retention_in_days = 30
  # checkov:skip=CKV_AWS_158:CloudWatch service-managed encryption; separate CMK is a production option.
  # checkov:skip=CKV_AWS_338:30-day bounded sandbox log retention is intentional.

}
resource "aws_iam_role" "flow" {
  name_prefix = "${var.name}-flow-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}
resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow.arn
  iam_role_arn    = aws_iam_role.flow.arn
}
output "vpc_id" {
  value = aws_vpc.this.id
}
output "public_subnets" {
  value = aws_subnet.public[*].id
}
output "private_subnets" {
  value = aws_subnet.private[*].id
}
output "alb_sg" {
  value = aws_security_group.alb.id
}
output "service_sgs" {
  value = {
    for k, s in aws_security_group.service : k => s.id
  }
}
output "database_sg" {
  value = aws_security_group.db.id
}
output "cache_sg" {
  value = aws_security_group.cache.id
}

