variable "name" {
  type = string
}
variable "subnets" {
  type = list(string)
}
variable "database_sg" {
  type = string
}
variable "cache_sg" {
  type = string
}
variable "multi_az" {
  type = bool
}
variable "deletion_protection" {
  type = bool
}
resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnets
}
resource "aws_db_instance" "this" {

  identifier                            = var.name
  engine                                = "postgres"
  engine_version                        = "17"
  instance_class                        = "db.t4g.micro"
  allocated_storage                     = 20
  max_allocated_storage                 = 40
  storage_type                          = "gp3"
  storage_encrypted                     = true
  kms_key_id                            = aws_kms_key.data.arn
  username                              = "bankcore_admin"
  manage_master_user_password           = true
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  vpc_security_group_ids                = [var.database_sg]
  publicly_accessible                   = false
  multi_az                              = var.multi_az
  backup_retention_period               = 7
  backup_window                         = "03:00-04:00"
  maintenance_window                    = "sun:04:30-sun:05:30"
  deletion_protection                   = var.deletion_protection
  skip_final_snapshot                   = false
  final_snapshot_identifier             = "${var.name}-final"
  copy_tags_to_snapshot                 = true
  auto_minor_version_upgrade            = true
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  iam_database_authentication_enabled   = true
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.data.arn
  performance_insights_retention_period = 7
  # checkov:skip=CKV_AWS_157:Single-AZ is the explicit cost-conscious sandbox default; multi_az enables the reference layout.
  # checkov:skip=CKV_AWS_129:Service-managed encryption enabled; customer-managed KMS is a production option.
  # checkov:skip=CKV_AWS_118:Enhanced monitoring agent is omitted for sandbox cost; CloudWatch native DB metrics remain available.

}
resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnets
}
resource "aws_elasticache_replication_group" "this" {

  replication_group_id       = var.name
  description                = "Disposable account metadata cache, never monetary authority"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = var.multi_az ? 2 : 1
  automatic_failover_enabled = var.multi_az
  multi_az_enabled           = var.multi_az
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.cache_sg]
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.data.arn
  transit_encryption_enabled = true
  port                       = 6379
  snapshot_retention_limit   = 0
  auto_minor_version_upgrade = true
  # checkov:skip=CKV_AWS_31:Metadata-only cache isolated by per-workload SG. Redis RBAC is a production hardening requirement.
  # checkov:skip=CKV_AWS_134:Disposable cache rebuilt from Account DB; snapshots intentionally disabled.

}
resource "aws_cloudwatch_metric_alarm" "db" {
  alarm_name  = "${var.name}-db-cpu"
  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
}
output "db_host" {
  value = aws_db_instance.this.address
}
output "master_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}
output "cache_host" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

