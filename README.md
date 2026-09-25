# Automating Amazon Textract Adapter Lifecycle Management Across Accounts

This repository contains sample code and infrastructure templates for the accompanying AWS blog post. It demonstrates how to automate Amazon Textract custom adapter lifecycle management across AWS accounts.

## Overview

When using Amazon Textract Custom Queries adapters in production, three core challenges emerge:

1. **Adapter promotion** — Moving trained adapters from development to production across AWS accounts
2. **Document routing** — Selecting the correct adapter per document when Amazon Textract supports one adapter per API call
3. **Production security** — Encryption, network isolation, least-privilege IAM, and audit logging

This sample provides reusable templates and patterns to address each challenge.

## Repository Structure

```
.
├── cloudformation/
│   └── textract-adapter-infrastructure.yaml   # IAM role + S3 buckets (CloudFormation)
├── terraform/
│   └── main.tf                                # IAM role + S3 buckets (Terraform equivalent)
├── scripts/
│   ├── create-adapter.sh                      # Create adapter and register in Parameter Store
│   ├── copy-adapter.sh                        # Validate a copied adapter in destination account
│   └── update-parameter.sh                    # Promote adapter by updating Parameter Store
└── src/
    ├── classify_and_route.py                  # Document pre-classification and adapter routing
    ├── sync_analyze.py                        # Synchronous AnalyzeDocument with adapter
    └── async_analyze.py                       # Asynchronous StartDocumentAnalysis with adapter
```

## Prerequisites

- An [AWS account](https://aws.amazon.com/free)
- IAM permissions to create and manage Amazon Textract adapters, Amazon S3 buckets, and AWS Systems Manager Parameter Store parameters
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured
- Sample documents (minimum 5 training and 5 test documents) for adapter training
- For multi-account promotion: access to both source and destination AWS accounts in the same Region

## Deployment

### Option 1: CloudFormation

```bash
aws cloudformation deploy \
  --template-file cloudformation/textract-adapter-infrastructure.yaml \
  --stack-name textract-adapter-infra \
  --capabilities CAPABILITY_IAM
```

### Option 2: Terraform

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

Both options create the same resources: an IAM role for Lambda-based Textract processing, a source S3 bucket for documents, and an output S3 bucket for results.

## Usage

### 1. Create and train an adapter

```bash
./scripts/create-adapter.sh \
  --name "insurance-claim-form-v2" \
  --feature-type QUERIES \
  --environment development
```

### 2. Classify and process a document

```python
from src.classify_and_route import classify_and_get_adapter

adapter_id = classify_and_get_adapter(raw_text)
```

### 3. Promote adapter to production

After validating in QA/staging, update the production parameter:

```bash
./scripts/update-parameter.sh \
  --adapter-id "your-destination-adapter-id" \
  --parameter-name "/textract/adapters/insurance-claim-v2/id"
```

## Security Considerations

- All S3 buckets enforce server-side encryption (AES256)
- Bucket policies deny non-HTTPS traffic
- Public access is fully blocked on all buckets
- IAM policies follow least-privilege principles
- For production workloads, consider enabling AWS KMS encryption and VPC endpoints for network isolation

## Important Notes

> **This is sample code for non-production usage.** Work with your security and legal teams to meet your organizational requirements before deployment.

- When copying adapters between accounts, only trained model weights transfer. Query definitions and training data are NOT copied.
- Source and destination accounts must be in the same AWS Region.
- Each adapter version requires its own separate copy request.

## Clean Up

```bash
# CloudFormation
aws cloudformation delete-stack --stack-name textract-adapter-infra

# Terraform
cd terraform/
terraform destroy
```

## Related Resources

- [Amazon Textract Custom Queries Documentation](https://docs.aws.amazon.com/textract/latest/dg/adapters.html)
- [AWS Blog: Automating Amazon Textract Adapter Lifecycle Management Across Accounts](https://aws.amazon.com/blogs/machine-learning/automating-amazon-textract-adapter-lifecycle-management-across-accounts/)

## Authors

- **Bhavya Sruthi Sode** — Technical Account Manager, AWS
- **Juan Pablo Arias Mora** — Customer Sentiment Intel Mgr, AWS

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
