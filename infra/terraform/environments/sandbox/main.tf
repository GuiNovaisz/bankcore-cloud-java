data "aws_caller_identity" "current" {

}
data "aws_partition" "current" {

}
locals {

  name = "bankcore-sandbox"
  services = {
    account-service = "account", ledger-service = "ledger", transfer-service = "transfer", projection-worker = "projection"
  }
  secret_names = toset(concat(["operator", "service"], flatten([for s in values(local.services) : ["${s}-app", "${s}-migrator"]])))

}
resource "random_password" "credential" {

  for_each = local.secret_names
  length   = 40
  special  = false

}
resource "aws_secretsmanager_secret" "credential" {

  for_each                = local.secret_names
  name_prefix             = "${local.name}-${each.key}-"
  recovery_window_in_days = 7
  # checkov:skip=CKV_AWS_149:Sandbox uses Secrets Manager service-managed encryption; CMK is a production option.
  # checkov:skip=CKV2_AWS_57:Rotation must coordinate DB users and ECS redeployment; runbook requires it before production.

}
resource "aws_secretsmanager_secret_version" "credential" {

  for_each      = local.secret_names
  secret_id     = aws_secretsmanager_secret.credential[each.key].id
  secret_string = random_password.credential[each.key].result

}
resource "aws_ecr_repository" "service" {

  for_each             = toset(concat(keys(local.services), ["collector", "bootstrap"]))
  name                 = "bankcore/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  encryption_configuration {
    encryption_type = "AES256"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
  # checkov:skip=CKV_AWS_136:AES256 encryption is enabled; dedicated CMKs are not required for the local-first sandbox target.

}
resource "aws_ecr_lifecycle_policy" "service" {

  for_each   = aws_ecr_repository.service
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1, description = "Remove untagged images after seven days", selection = {
        tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7
        }, action = {
        type = "expire"
      }
    }]
  })

}
module "network" {

  source         = "../../modules/networking"
  name           = local.name
  region         = var.region
  account_id     = data.aws_caller_identity.current.account_id
  operator_cidrs = var.operator_cidrs

}
module "messaging" {
  source = "../../modules/messaging"
  name   = local.name
}
module "data" {

  source              = "../../modules/data"
  name                = local.name
  subnets             = module.network.private_subnets
  database_sg         = module.network.database_sg
  cache_sg            = module.network.cache_sg
  multi_az            = var.multi_az
  deletion_protection = var.deletion_protection

}
module "runtime" {

  source           = "../../modules/runtime"
  name             = local.name
  region           = var.region
  account_id       = data.aws_caller_identity.current.account_id
  vpc_id           = module.network.vpc_id
  private_subnets  = module.network.private_subnets
  public_subnets   = module.network.public_subnets
  alb_sg           = module.network.alb_sg
  service_sgs      = module.network.service_sgs
  certificate_arn  = var.certificate_arn
  services         = local.services
  image_digests    = var.image_digests
  desired_count    = var.desired_count
  db_host          = module.data.db_host
  db_master_secret = module.data.master_secret_arn
  cache_host       = module.data.cache_host
  queue_url        = module.messaging.queue_url
  queue_arn        = module.messaging.queue_arn
  credentials = {
    for k, s in aws_secretsmanager_secret.credential : k => s.arn
  }

}
output "bootstrap_task_definition" {
  value = module.runtime.bootstrap_task_definition
}
output "cluster" {
  value = module.runtime.cluster
}
output "private_subnets" {
  value = module.network.private_subnets
}
output "bootstrap_sg" {
  value = module.network.service_sgs["bootstrap"]
}
output "alb_dns" {
  value = module.runtime.alb_dns
}
output "queue_url" {
  value = module.messaging.queue_url
}
output "ecr_repositories" {
  value = {
    for k, r in aws_ecr_repository.service : k => r.repository_url
  }
}

