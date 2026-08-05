# Supporting infrastructure for Amazon Textract adapter workloads

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "source_bucket_name" {
  description = "Name of the S3 bucket for input documents"
  type        = string
  default     = "amzn-s3-demo-source-bucket"
}

variable "output_bucket_name" {
  description = "Name of the S3 bucket for Textract output"
  type        = string
  default     = "amzn-s3-demo-destination-bucket"
}

variable "adapter_id" {
  description = "Adapter ID (set after creation or copy)"
  type        = string
  default     = ""
}

# IAM Role for Textract processing
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
}

resource "aws_iam_role_policy" "textract_access" {
  name = "TextractAdapterAccess"
  role = aws_iam_role.textract_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "textract:AnalyzeDocument",
          "textract:StartDocumentAnalysis",
          "textract:GetDocumentAnalysis"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.documents.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.output.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/textract/adapters/*"
      }
    ]
  })
}

# S3 Buckets
resource "aws_s3_bucket" "documents" {
  bucket = var.source_bucket_name
}

resource "aws_s3_bucket" "output" {
  bucket = var.output_bucket_name
}

# Adapter creation via terraform_data (temporary workaround)
# Note: Check periodically if native Terraform provider support has been added
# for Amazon Textract adapter resources.
resource "terraform_data" "create_adapter" {
  provisioner "local-exec" {
    command = <<-EOT
      aws textract create-adapter \
        --adapter-name "insurance-claim-form-v2" \
        --feature-types QUERIES \
        --auto-update ENABLED
    EOT
  }
}

# Store adapter IDs in Parameter Store
resource "aws_ssm_parameter" "adapter_id" {
  name  = "/textract/adapters/insurance-claim-v2/id"
  type  = "String"
  value = var.adapter_id
}
