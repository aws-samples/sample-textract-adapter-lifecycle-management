# Automating Amazon Textract Adapter Lifecycle Management Across Accounts

This repository contains sample code and infrastructure-as-code templates that demonstrate how to automate Amazon Textract custom adapter lifecycle management across AWS accounts.

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
│   └── textract-adapter-infrastructure.yaml   # Supporting infrastructure (IAM, S3, KMS, SSM)
├── terraform/
│   └── main.tf                                # Terraform equivalent with terraform_data adapter creation
├── scripts/
│   ├── create-adapter.sh                      # CLI script for adapter creation and SSM registration
│   ├── copy-adapter.sh                        # CLI script for cross-account adapter validation
│   └── update-parameter.sh                    # CLI script for promoting adapter references
└── src/
    ├── classify_and_route.py                  # Document pre-classification and adapter routing
    ├── sync_analyze.py                        # Synchronous AnalyzeDocument with adapter
    └── async_analyze.py                       # Asynchronous StartDocumentAnalysis with adapter
```

## Prerequisites

- An [AWS account](https://aws.amazon.com/free)
- IAM permissions to create and manage Amazon Textract adapters, Amazon S3 buckets, AWS KMS keys, and AWS Systems Manager Parameter Store parameters
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured
- Sample documents (minimum 5 training and 5 test documents) for adapter training
- For multi-account promotion: access to both source and destination AWS accounts in the same Region
- (Optional) AWS CloudFormation or Terraform for infrastructure-as-code deployment

## Deployment

### CloudFormation

```bash
aws cloudformation deploy \
  --template-file cloudformation/textract-adapter-infrastructure.yaml \
  --stack-name textract-adapter-infra \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    SourceBucketName=your-source-bucket \
    OutputBucketName=your-output-bucket
```

### Terraform

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

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

# Get the correct adapter based on document content
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

- All S3 buckets enforce server-side encryption with AWS KMS
- API calls route through AWS PrivateLink for network isolation
- IAM policies follow least-privilege principles
- AWS CloudTrail provides API audit logging
- Amazon CloudWatch handles operational monitoring and alerting

## Important Notes

> **This is sample code, for non-production usage.** You should work with your security and legal teams to meet your organizational security, regulatory and compliance requirements before deployment.

- When copying adapters between accounts, only trained model weights transfer. Query definitions and training data are NOT copied.
- Source and destination accounts must be in the same AWS Region. Cross-region copies are not supported.
- Each adapter version requires its own separate copy request.

## Related Resources

- [Amazon Textract Custom Queries Documentation](https://docs.aws.amazon.com/textract/latest/dg/adapters.html)
- [AWS Blog: Automating Amazon Textract Adapter Lifecycle Management Across Accounts](#) *(link to be updated upon publication)*

## Authors

- **Bhavya Sruthi Sode** — Technical Account Manager, AWS (US Retail & CPG)
- **Juan Pablo Arias Mora** — Senior Technical Account Manager, AWS (Financial Services)

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
