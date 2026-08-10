# Supporting infrastructure for Amazon Textract adapter workloads
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  # Region is inherited from AWS_DEFAULT_REGION or ~/.aws/config
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- IAM Role for Lambda-based Textract processing ---
resource "aws_iam_role" "textract_role" {
  name = "textract-adapter-processing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_iam_role_policy" "textract_access" {
  name = "TextractAdapterAccess"
  role = aws_iam_role.textract_role.id

  # Amazon Textract AnalyzeDocument, StartDocumentAnalysis, and
  # GetDocumentAnalysis do not support resource-level permissions.
  # These actions require Resource: "*" — this is an AWS service
  # limitation, not a least-privilege gap.
  # Reference: https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazontextract.html
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TextractAnalysis"
        Effect = "Allow"
        Action = [
          "textract:AnalyzeDocument",
          "textract:StartDocumentAnalysis",
          "textract:GetDocumentAnalysis"
        ]
        Resource = "*"
      },
      {
        Sid      = "S3ReadSource"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.documents.arn}/*"
      },
      {
        Sid      = "S3WriteOutput"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.output.arn}/*"
      },
      {
        Sid      = "SSMReadParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/textract/adapters/*"
      }
    ]
  })
}

# --- S3 Buckets (auto-generated names, no hardcoding) ---
# For production workloads, consider enabling AWS KMS encryption.
# See: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html

resource "aws_s3_bucket" "documents" {
  # No bucket name specified — Terraform generates a unique name
  force_destroy = true

  tags = {
    Purpose = "Textract adapter source documents"
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket                  = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "output" {
  force_destroy = true

  tags = {
    Purpose = "Textract adapter output results"
  }
}

resource "aws_s3_bucket_versioning" "output" {
  bucket = aws_s3_bucket.output.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output" {
  bucket = aws_s3_bucket.output.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "output" {
  bucket                  = aws_s3_bucket.output.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Outputs ---
output "processing_role_arn" {
  description = "ARN of the Textract processing IAM role"
  value       = aws_iam_role.textract_role.arn
}

output "document_bucket_name" {
  description = "Name of the source document bucket"
  value       = aws_s3_bucket.documents.id
}

output "output_bucket_name" {
  description = "Name of the output bucket"
  value       = aws_s3_bucket.output.id
}
