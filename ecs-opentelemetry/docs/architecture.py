from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECS, ECR
from diagrams.aws.database import Aurora
from diagrams.aws.network import ALB, PrivateSubnet, PublicSubnet, Route53
from diagrams.aws.management import Cloudwatch
from diagrams.aws.security import SecretsManager
from diagrams.aws.devtools import XRay
from diagrams.onprem.client import User

with Diagram("ECS OpenTelemetry ToDo Application", show=False, filename="docs/architecture", outformat="png"):
    user = User("User")

    with Cluster("AWS Cloud"):
        with Cluster("VPC"):
            with Cluster("Public Subnet"):
                alb = ALB("Application Load Balancer")

            with Cluster("Private Subnet"):
                with Cluster("ECS Task (Next.js)"):
                    nextjs_app = ECS("Next.js App")
                    otel_sidecar1 = ECS("OTel Collector")
                    nextjs_app >> Edge(label="OTLP") >> otel_sidecar1

                with Cluster("ECS Task (FastAPI)"):
                    fastapi_app = ECS("FastAPI App")
                    otel_sidecar2 = ECS("OTel Collector")
                    fastapi_app >> Edge(label="OTLP") >> otel_sidecar2

                db = Aurora("Aurora Serverless v2")

            cloud_map = Route53("Cloud Map")
            secrets_manager = SecretsManager("Secrets Manager")

        with Cluster("AWS Observability"):
            cw = Cloudwatch("CloudWatch")
            xray = XRay("X-Ray")

        ecr = ECR("ECR")

    user >> alb >> nextjs_app
    nextjs_app >> Edge(label="API Call via Service Discovery") >> fastapi_app
    fastapi_app >> db
    fastapi_app >> Edge(color="darkgrey", style="dotted") >> secrets_manager

    otel_sidecar1 >> cw
    otel_sidecar1 >> xray
    otel_sidecar2 >> cw
    otel_sidecar2 >> xray

    nextjs_app << Edge(label="Image Pull", color="darkgrey", style="dotted") << ecr
    fastapi_app << Edge(label="Image Pull", color="darkgrey", style="dotted") << ecr
    fastapi_app >> Edge(color="darkgrey", style="dotted") >> cloud_map
