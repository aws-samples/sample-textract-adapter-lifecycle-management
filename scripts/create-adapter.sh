#!/bin/bash
# Create a new Amazon Textract adapter and register it in Parameter Store.
#
# Usage:
#   ./create-adapter.sh --name <adapter-name> --feature-type <QUERIES|FORMS|TABLES> --environment <env>
#
# Example:
#   ./create-adapter.sh --name "insurance-claim-form-v2" --feature-type QUERIES --environment development

set -euo pipefail

# Parse arguments
ADAPTER_NAME=""
FEATURE_TYPE="QUERIES"
ENVIRONMENT="development"

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) ADAPTER_NAME="$2"; shift 2 ;;
    --feature-type) FEATURE_TYPE="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ADAPTER_NAME" ]]; then
  echo "Error: --name is required"
  exit 1
fi

echo "Creating adapter: $ADAPTER_NAME (feature type: $FEATURE_TYPE, environment: $ENVIRONMENT)"

# Create the adapter
RESPONSE=$(aws textract create-adapter \
  --adapter-name "$ADAPTER_NAME" \
  --feature-types '["'"$FEATURE_TYPE"'"]' \
  --auto-update ENABLED \
  --tags "Environment=$ENVIRONMENT,FormType=$ADAPTER_NAME" \
  --output json)

ADAPTER_ID=$(echo "$RESPONSE" | jq -r '.AdapterId')

if [[ -z "$ADAPTER_ID" || "$ADAPTER_ID" == "null" ]]; then
  echo "Error: Failed to create adapter"
  echo "$RESPONSE"
  exit 1
fi

echo "Adapter created successfully: $ADAPTER_ID"

# Store the adapter ID in Parameter Store
PARAM_NAME="/textract/adapters/${ADAPTER_NAME}/id"
aws ssm put-parameter \
  --name "$PARAM_NAME" \
  --type String \
  --value "$ADAPTER_ID" \
  --overwrite

echo "Adapter ID stored in Parameter Store: $PARAM_NAME = $ADAPTER_ID"
echo ""
echo "Next steps:"
echo "  1. Train the adapter with your document set"
echo "  2. Validate extraction accuracy"
echo "  3. Promote to downstream environments"
