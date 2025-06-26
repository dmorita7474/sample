
# Log group for ADOT collector metrics (EMF)
resource "aws_cloudwatch_log_group" "adot_metrics" {
  name              = "/ecs/ecs-adot-metrics"
  retention_in_days = 14
}

# Log group for the ADOT collector container itself
resource "aws_cloudwatch_log_group" "adot_collector_logs" {
  name              = "/ecs/aws-otel-collector"
  retention_in_days = 14
}

# ADOT collector configuration stored in SSM Parameter Store
resource "aws_ssm_parameter" "adot_config" {
  name  = "/ecs-opentelemetry/adot-config"
  type  = "String"
  value = <<-EOT
receivers:
  otlp:
    protocols:
      grpc:
      http:

exporters:
  awsxray:
    region: "ap-northeast-1"
  awsemf:
    region: "ap-northeast-1"
    log_group_name: ${aws_cloudwatch_log_group.adot_metrics.name}
    log_stream_name: "ecs-adot-metrics-stream"

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [awsxray]
    metrics:
      receivers: [otlp]
      exporters: [awsemf]
EOT
}

# IAM policy to allow reading the ADOT config from SSM
resource "aws_iam_policy" "ssm_adot_config_access" {
  name        = "ssm-adot-config-access-policy"
  description = "Allow reading ADOT config from SSM"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = "ssm:GetParameters",
        Effect   = "Allow",
        Resource = aws_ssm_parameter.adot_config.arn
      }
    ]
  })
}

# Attach the SSM policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_ssm_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ssm_adot_config_access.policy_arn
}
