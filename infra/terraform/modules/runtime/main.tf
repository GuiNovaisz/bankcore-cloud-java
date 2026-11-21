locals {

  workloads = toset(concat(keys(var.services), ["collector", "bootstrap"]))
  trust = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })

}
resource "aws_ecs_cluster" "this" {
  name = var.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_cloudwatch_log_group" "service" {
  for_each          = local.workloads
  name              = "/bankcore/${each.key}"
  retention_in_days = 30
  # checkov:skip=CKV_AWS_158:CloudWatch managed encryption; CMK optional for reference production.
  # checkov:skip=CKV_AWS_338:30-day bounded sandbox retention is intentional.

}
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "bankcore.internal"
  vpc  = var.vpc_id
}
resource "aws_service_discovery_service" "this" {
  for_each = toset(concat(keys(var.services), ["collector"]))
  name     = each.key
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
  }
}
resource "aws_iam_role" "execution" {
  for_each           = local.workloads
  name_prefix        = "${var.name}-${each.key}-exec-"
  assume_role_policy = local.trust
}
resource "aws_iam_role" "task" {
  for_each           = local.workloads
  name_prefix        = "${var.name}-${each.key}-task-"
  assume_role_policy = local.trust
}
resource "aws_iam_role_policy" "execution" {
  for_each = local.workloads
  role     = aws_iam_role.execution[each.key].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = concat([
      {
        Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*"
      },
      {
        Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = "arn:aws:ecr:${var.region}:${var.account_id}:repository/bankcore/${each.key}"
      },
      {
        Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.service[each.key].arn}:*"
      }],
      contains(keys(var.services), each.key) ? [{
        Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [var.credentials["operator"], var.credentials["service"], var.credentials["${var.services[each.key]}-app"], var.credentials["${var.services[each.key]}-migrator"]]
      }] : [],
      each.key == "bootstrap" ? [{
        Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = concat([var.db_master_secret], [for s in values(var.services) : var.credentials["${s}-app"]], [for s in values(var.services) : var.credentials["${s}-migrator"]])
    }] : [])
  })
}
resource "aws_iam_role_policy" "producer" {
  role = aws_iam_role.task["ledger-service"].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["sqs:SendMessage"], Resource = var.queue_arn
    }]
  })
}
resource "aws_iam_role_policy" "consumer" {
  role = aws_iam_role.task["projection-worker"].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"], Resource = var.queue_arn
    }]
  })
}
resource "aws_iam_role_policy" "traces" {
  role = aws_iam_role.task["collector"].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"], Resource = "*"
    }]
  })
}
resource "aws_ecs_task_definition" "service" {
  for_each                 = var.services
  family                   = "${var.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution[each.key].arn
  task_role_arn            = aws_iam_role.task[each.key].arn
  container_definitions = jsonencode([{
    name = each.key, image = var.image_digests[each.key], essential = true, user = "1000", readonlyRootFilesystem = true,
    portMappings = [{
      containerPort = 8080
    }], stopTimeout = 35,
    linuxParameters = {
      initProcessEnabled = true
    },
    mountPoints = [{
      sourceVolume = "tmp", containerPath = "/tmp", readOnly = false
    }],
    environment = [for k, v in {

      DB_URL                             = "jdbc:postgresql://${var.db_host}:5432/${each.value}?sslmode=require", DB_USER = "${each.value}_app", MIGRATION_USER = "${each.value}_migrator",
      ACCOUNT_URL                        = "http://account-service.bankcore.internal:8080", LEDGER_URL = "http://ledger-service.bankcore.internal:8080",
      REDIS_HOST                         = var.cache_host, SPRING_DATA_REDIS_SSL_ENABLED = "true", QUEUE_URL = var.queue_url, AWS_REGION = var.region,
      OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://collector.bankcore.internal:4318/v1/traces"

      } : {
      name = k, value = v
    }],
    secrets = [{
      name = "DB_PASSWORD", valueFrom = var.credentials["${each.value}-app"]
      }, {
      name = "MIGRATION_PASSWORD", valueFrom = var.credentials["${each.value}-migrator"]
      }, {
      name = "OPERATOR_PASSWORD", valueFrom = var.credentials["operator"]
      }, {
      name = "SERVICE_PASSWORD", valueFrom = var.credentials["service"]
    }],
    healthCheck = {
      command = ["CMD-SHELL", "curl -fsS http://localhost:8080/actuator/health/readiness || exit 1"], interval = 15, timeout = 3, retries = 3, startPeriod = 60
    },
    logConfiguration = {
      logDriver = "awslogs", options = {
        awslogs-group = aws_cloudwatch_log_group.service[each.key].name, awslogs-region = var.region, awslogs-stream-prefix = "ecs"
      }
    }
  }])
  volume {
    name = "tmp"
  }
  # checkov:skip=CKV_AWS_97:No privileged mode; nonroot fixed UID and readonly root filesystem are enabled.

}
resource "aws_lb" "this" {
  name                       = var.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg]
  subnets                    = var.public_subnets
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  # checkov:skip=CKV_AWS_91:ALB access logging needs separately governed S3 retention. Application logs and VPC flows are provisioned.
  # checkov:skip=CKV2_AWS_28:CIDR-restricted sandbox ALB; WAF is a production hardening option.
  # checkov:skip=CKV2_AWS_20:HTTPS only listener; port 80 is closed instead of redirecting.

}
resource "aws_lb_target_group" "this" {
  for_each             = var.services
  name                 = "bankcore-${each.value}"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30
  health_check {
    path    = "/actuator/health/readiness"
    matcher = "200"
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"title\":\"NOT_FOUND\",\"status\":404}"
      status_code  = "404"
    }
  }
}
locals {
  routes = {

    balance = {
      priority = 10, service = "ledger-service", paths = ["/accounts/*/balance"]
    },
    account = {
      priority = 20, service = "account-service", paths = ["/accounts", "/accounts/*"]
    },
    transfer = {
      priority = 30, service = "transfer-service", paths = ["/transfers", "/transfers/*"]
    },
    ledger = {
      priority = 40, service = "ledger-service", paths = ["/journals"]
    },
    projection = {
      priority = 50, service = "projection-worker", paths = ["/projections/*"]
    }

  }
}
resource "aws_lb_listener_rule" "routes" {
  for_each     = local.routes
  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.service].arn
  }
  condition {
    path_pattern {
      values = each.value.paths
    }
  }
}
resource "aws_ecs_service" "this" {
  for_each                           = var.services
  name                               = each.key
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  enable_execute_command             = false
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.service_sgs[each.key]]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    container_name   = each.key
    container_port   = 8080
  }
  service_registries {
    registry_arn = aws_service_discovery_service.this[each.key].arn
  }
  depends_on = [aws_lb_listener_rule.routes]
  lifecycle {
    ignore_changes = [desired_count]
  }

}
resource "aws_appautoscaling_target" "this" {
  for_each           = var.services
  max_capacity       = 2
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "cpu" {
  for_each           = var.services
  name               = "${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  for_each    = var.services
  alarm_name  = "${var.name}-${each.key}-unhealthy"
  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix, TargetGroup = aws_lb_target_group.this[each.key].arn_suffix
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}
resource "aws_cloudwatch_metric_alarm" "latency" {
  alarm_name  = "${var.name}-latency"
  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}
output "cluster" {
  value = aws_ecs_cluster.this.name
}
output "alb_dns" {
  value = aws_lb.this.dns_name
}
output "bootstrap_task_definition" {
  value = aws_ecs_task_definition.bootstrap.arn
}

