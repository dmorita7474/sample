###############################################################################
# 対象リソース: CloudFront, S3, API Gateway
###############################################################################
# ドメイン名とACMは既に用意してあるものを指定
variable "backend_status_code" {
  type        = number
  description = "backend status code"
  default     = 200
}

data "aws_caller_identity" "current" {}

# フロントエンド用S3バケット
module "s3_frontend" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = "frontend-${data.aws_caller_identity.current.account_id}"

  versioning = {
    enabled = true
  }
}

# バックエンド用API Gateway
resource "aws_api_gateway_rest_api" "backend" {
  name = "backend"
  body = templatefile("${path.module}/files/backend-dev-oas30-apigateway.yaml", { status_code = var.backend_status_code })

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "dev" {
  rest_api_id = aws_api_gateway_rest_api.backend.id

  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.backend.body)
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.dev.id
  rest_api_id   = aws_api_gateway_rest_api.backend.id
  stage_name    = "dev"
}

# フロントエンド、バックエンドの前段に配置するCloudFront
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.1"

  #aliases = [var.domain_name]

  comment          = "Sample CloudFront"
  enabled          = true
  price_class      = "PriceClass_200"
  retain_on_delete = false

  origin = {
    frontend = {
      domain_name           = module.s3_frontend.s3_bucket_bucket_domain_name
      origin_access_control = "frontend"
    }
    backend = {
      domain_name = "${aws_api_gateway_rest_api.backend.id}.execute-api.ap-northeast-1.amazonaws.com"
      origin_path = "/dev"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "frontend"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    # 以下のエラーのワークアラウンド対応
    # https://github.com/pulumi/pulumi-aws/issues/1364
    use_forwarded_values = false
    compress             = true
    # マネージドポリシーのIDは環境依存ではなく固定。
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
    function_association = {
      # 通常用
      "viewer-request" = {
        function_arn = aws_cloudfront_function.main.arn
      }
      #"viewer-response" = {
      #  function_arn = aws_cloudfront_function.viewer_response.arn
      #}
      # エラーページ用
      #"viewer-request" = {
      #  function_arn = aws_cloudfront_function.error_request.arn
      #}
      #"viewer-response" = {
      #  function_arn = aws_cloudfront_function.error_response.arn
      #}
    }
    lambda_function_association = {
      "origin-response" = {
        lambda_arn = module.lambda_at_edge.lambda_function_qualified_arn
      }
    }
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/api/*"
      target_origin_id       = "backend"
      viewer_protocol_policy = "https-only"

      use_forwarded_values = false
      allowed_methods      = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      # この構成ではHostヘッダは転送対象から除外する必要がある。
      # https://oji-cloud.net/2020/12/07/post-5752/#
      cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
      origin_request_policy_id   = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader
      response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03" # Managed-SecurityHeadersPolicy
    }
  ]

  # OAIではなくOACが今後の推奨
  # https://docs.aws.amazon.com/ja_jp/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html
  create_origin_access_control = true
  origin_access_control = {
    "frontend" = {
      description      = ""
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
  } }

  #custom_error_response = [
  #  {
  #    error_code         = 404
  #    response_code      = 404
  #    response_page_path = "/error404.html"
  #  },
  #  {
  #    error_code         = 503
  #    response_code      = 503
  #    response_page_path = "/error500.html"
  #  }
  #]
}

# index機能用function
resource "aws_cloudfront_function" "main" {
  name    = "rewrite-trailing-srash"
  runtime = "cloudfront-js-2.0"
  comment = "Rewriting trailin slash"
  publish = true
  code    = file("${path.module}/files/trailing-slash.js")
}

# エラー対応function
#resource "aws_cloudfront_function" "maintenance_request" {
#  name    = "error-request"
#  runtime = "cloudfront-js-2.0"
#  comment = "Error for request"
#  publish = true
#  code    = file("${path.module}/files/error-request.js")
#}

resource "aws_cloudfront_function" "viewer_response" {

  name    = "viewer-response"
  runtime = "cloudfront-js-2.0"
  comment = "Viewer response"
  publish = true
  code    = file("${path.module}/files/viewer-response.js")
}

provider "aws" {
  region = "us-east-1"
  alias  = "use1"
}

module "lambda_at_edge" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.17.0"

  providers = {
    aws = aws.use1
  }

  lambda_at_edge = true

  function_name = "lambda-at-edge"
  description   = "lambda@edge function"
  handler       = "index.handler"
  runtime       = "nodejs22.x"

  source_path = "${path.module}/files/lambda-edge"
  publish     = true
}


# S3バケット、CloudFront、S3バケットポリシーの順番で作成するが、s3_frontendモジュール上でBucket Policyを指定するとCycleが発生するため、
# バケットポリシーだけresourceブロックで定義
locals {
  static_contents_source_arn = module.cloudfront.cloudfront_distribution_arn
}

data "aws_iam_policy_document" "bp_frontend" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject"]
    resources = [
      "${module.s3_frontend.s3_bucket_arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.static_contents_source_arn]
    }
  }

  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:ListBucket"]
    resources = [
      "${module.s3_frontend.s3_bucket_arn}"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.static_contents_source_arn]
    }
  }

  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      "${module.s3_frontend.s3_bucket_arn}/*",
      module.s3_frontend.s3_bucket_arn,
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = module.s3_frontend.s3_bucket_id
  policy = data.aws_iam_policy_document.bp_frontend.json
}

resource "aws_s3_object" "error_page_500" {
  bucket       = module.s3_frontend.s3_bucket_id
  key          = "error500.html"
  source       = "${path.module}/files/error500.html"
  content_type = "text/html"

  etag = filemd5("${path.module}/files/error500.html")
}

resource "aws_s3_object" "error_page_404" {
  bucket       = module.s3_frontend.s3_bucket_id
  key          = "error404.html"
  source       = "${path.module}/files/error404.html"
  content_type = "text/html"

  etag = filemd5("${path.module}/files/error404.html")
}
