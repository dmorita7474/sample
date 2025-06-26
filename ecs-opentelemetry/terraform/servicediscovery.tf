
# Private DNS namespace for service discovery within the VPC
resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "Private DNS namespace for service discovery"
  vpc         = module.vpc.vpc_id
}

# Service discovery service for the FastAPI application
resource "aws_service_discovery_service" "fastapi" {
  name = "fastapi"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    # ECS manages the health of the tasks, so we don't need a separate health check here.
    # A failure_threshold of 1 means that if a task is unhealthy, it will be quickly removed from DNS.
    failure_threshold = 1
  }
}
