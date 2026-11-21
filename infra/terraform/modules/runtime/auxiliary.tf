locals {

  collector_config = yamlencode({
    receivers = {
      otlp = {
        protocols = {
          http = {
            endpoint = "0.0.0.0:4318"
          }
        }
      }
      }, processors = {
      batch = {

      }
      }, exporters = {
      awsxray = {
        region = var.region
      }
      }, service = {
      pipelines = {
        traces = {
          receivers = ["otlp"], processors = ["batch"], exporters = ["awsxray"]
        }
      }
    }
  })

}
resource "aws_ecs_task_definition" "collector" {
  family                   = "${var.name}-collector"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution["collector"].arn
  task_role_arn            = aws_iam_role.task["collector"].arn
  container_definitions = jsonencode([{
    name = "collector", image = var.image_digests["collector"], essential = true, user = "10001", readonlyRootFilesystem = true,
    portMappings = [{
      containerPort = 4318
      }], command = ["--config=env:OTEL_CONFIG"], environment = [{
      name = "OTEL_CONFIG", value = local.collector_config
    }],
    logConfiguration = {
      logDriver = "awslogs", options = {
        awslogs-group = aws_cloudwatch_log_group.service["collector"].name, awslogs-region = var.region, awslogs-stream-prefix = "ecs"
      }
    }
  }])
}
resource "aws_ecs_service" "collector" {
  name            = "collector"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.collector.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.service_sgs["collector"]]
    assign_public_ip = false
  }
  service_registries {
    registry_arn = aws_service_discovery_service.this["collector"].arn
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
resource "aws_ecs_task_definition" "bootstrap" {
  family                   = "${var.name}-bootstrap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution["bootstrap"].arn
  task_role_arn            = aws_iam_role.task["bootstrap"].arn
  container_definitions = jsonencode([{
    name = "bootstrap", image = var.image_digests["bootstrap"], essential = true, user = "999", readonlyRootFilesystem = true,
    entryPoint = ["sh", "-ec"], command = [join("\n", [for s in values(var.services) : <<-SCRIPT
 psql -X -v ON_ERROR_STOP=1 <<'SQL'
 \getenv app_password ${upper(s)}_APP_PASSWORD
 \getenv migration_password ${upper(s)}_MIGRATION_PASSWORD
 SELECT format('CREATE ROLE ${s}_migrator LOGIN PASSWORD %L', :'migration_password') WHERE NOT EXISTS(SELECT FROM pg_roles WHERE rolname='${s}_migrator') \gexec
 SELECT format('CREATE ROLE ${s}_app LOGIN PASSWORD %L', :'app_password') WHERE NOT EXISTS(SELECT FROM pg_roles WHERE rolname='${s}_app') \gexec
 SELECT 'CREATE DATABASE ${s} OWNER ${s}_migrator' WHERE NOT EXISTS(SELECT FROM pg_database WHERE datname='${s}') \gexec
 REVOKE ALL ON DATABASE ${s} FROM PUBLIC;
 GRANT CONNECT ON DATABASE ${s} TO ${s}_app;
 \connect ${s}
 REVOKE CREATE ON SCHEMA public FROM PUBLIC;
 GRANT USAGE ON SCHEMA public TO ${s}_app;
 ALTER DEFAULT PRIVILEGES FOR ROLE ${s}_migrator IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO ${s}_app;
 ALTER DEFAULT PRIVILEGES FOR ROLE ${s}_migrator IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO ${s}_app;
 SQL
 SCRIPT
      ])], environment = [{
      name = "PGHOST", value = var.db_host
      }, {
      name = "PGUSER", value = "bankcore_admin"
      }, {
      name = "PGDATABASE", value = "postgres"
      }, {
      name = "PGSSLMODE", value = "require"
    }],
    secrets = concat([{
      name = "PGPASSWORD", valueFrom = "${var.db_master_secret}:password::"
      }], flatten([for s in values(var.services) : [{
        name = "${upper(s)}_APP_PASSWORD", valueFrom = var.credentials["${s}-app"]
        }, {
        name = "${upper(s)}_MIGRATION_PASSWORD", valueFrom = var.credentials["${s}-migrator"]
    }]])),
    logConfiguration = {
      logDriver = "awslogs", options = {
        awslogs-group = aws_cloudwatch_log_group.service["bootstrap"].name, awslogs-region = var.region, awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

