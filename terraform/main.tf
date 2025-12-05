terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway = "http://localhost:4566"
    sts        = "http://localhost:4566"
    iam        = "http://localhost:4566"
    lambda     = "http://localhost:4566"
  }
}

data "archive_file" "jwt_authorizer_zip" {
  type        = "zip"
  source_file = "${path.module}/jwt_authorizer.py"
  output_path = "${path.module}/jwt-authorizer.zip"
}

resource "aws_iam_role" "jwt_authorizer_role" {
  name = "localstack-jwt-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_lambda_function" "jwt_authorizer" {
  function_name = "jwt-authorizer"
  role          = aws_iam_role.jwt_authorizer_role.arn
  handler       = "jwt_authorizer.handler"
  runtime       = "python3.11"

  filename         = data.archive_file.jwt_authorizer_zip.output_path
  source_code_hash = data.archive_file.jwt_authorizer_zip.output_base64sha256
}

resource "aws_api_gateway_rest_api" "orders_api" {
  name        = "orders-api"
  description = "Orders API running on LocalStack"
}

resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  parent_id   = aws_api_gateway_rest_api.orders_api.root_resource_id
  path_part   = "order"
}

resource "aws_api_gateway_authorizer" "jwt_authorizer" {
  name          = "jwt-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  type          = "REQUEST"
  authorizer_uri = aws_lambda_function.jwt_authorizer.invoke_arn
}

resource "aws_api_gateway_method" "get_order" {
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"

  authorizer_id = aws_api_gateway_authorizer.jwt_authorizer.id
}

resource "aws_api_gateway_integration" "get_order_mock" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.get_order.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "get_order_200" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.get_order.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "get_order_integration_200" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.get_order.http_method
  status_code = aws_api_gateway_method_response.get_order_200.status_code

  response_templates = {
    "application/json" = "{\"orderId\": \"ORD-123\", \"customerId\": \"CUST-456\", \"totalAmount\": 99.99, \"status\": \"CONFIRMED\"}"
  }
}

resource "aws_lambda_permission" "apigw_invoke_jwt_authorizer" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jwt_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:000000000000:${aws_api_gateway_rest_api.orders_api.id}/*/*/*"
}

resource "aws_api_gateway_deployment" "orders_deployment" {
  depends_on = [
    aws_api_gateway_integration.get_order_mock,
    aws_api_gateway_integration_response.get_order_integration_200,
    aws_api_gateway_authorizer.jwt_authorizer,
  ]

  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  stage_name  = "dev"

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.get_order_mock.id,
      aws_api_gateway_integration_response.get_order_integration_200.id,
      aws_api_gateway_authorizer.jwt_authorizer.id,
    ]))
  }
}

output "api_invoke_url" {
  value = "http://localhost:4566/_aws/execute-api/${aws_api_gateway_rest_api.orders_api.id}/dev/order"
}
