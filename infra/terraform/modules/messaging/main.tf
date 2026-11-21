variable "name" {
  type = string
}
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}
resource "aws_sqs_queue" "events" {
  name                       = "${var.name}-events"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 10
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn, maxReceiveCount = 3
  })
}
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.url
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue", sourceQueueArns = [aws_sqs_queue.events.arn]
  })
}
resource "aws_sqs_queue_policy" "tls" {
  for_each = {
    events = aws_sqs_queue.events, dlq = aws_sqs_queue.dlq
  }
  queue_url = each.value.url
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Deny", Principal = "*", Action = "sqs:*", Resource = each.value.arn, Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}
resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name  = "${var.name}-dlq"
  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}
resource "aws_cloudwatch_metric_alarm" "lag" {
  alarm_name  = "${var.name}-queue-age"
  namespace   = "AWS/SQS"
  metric_name = "ApproximateAgeOfOldestMessage"
  dimensions = {
    QueueName = aws_sqs_queue.events.name
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 60
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}
output "queue_url" {
  value = aws_sqs_queue.events.url
}
output "queue_arn" {
  value = aws_sqs_queue.events.arn
}

