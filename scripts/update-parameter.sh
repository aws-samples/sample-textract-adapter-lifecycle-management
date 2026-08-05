#!/bin/bash
# Update Parameter Store with a new adapter ID after promotion.
#
# Because application code retrieves the adapter ID from SSM at runtime,
# no code deployment is needed - only the parameter update.
#
# Usage:
#   ./update-parameter.sh --adapter-id <id> --parameter-name <ssm-param-name>
#
# Example:
#   ./update-parameter.sh \
#     --adapter-id "x9y8z7w6v5u4" \
#     --parameter-name "/textract/adapters/insurance-claim-v2/id"

set -euo pipefail

# Parse arguments
ADAPTER_ID=""
PARAM_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --adapter-id) ADAPTER_ID="$2"; shift 2 ;;
    --parameter-name) PARAM_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ADAPTER_ID" || -z "$PARAM_NAME" ]]; then
  echo "Error: --adapter-id and --parameter-name are required"
  echo "Usage: ./update-parameter.sh --adapter-id <id> --parameter-name <ssm-param-name>"
  exit 1
fi

# Get current value for audit trail
CURRENT=$(aws ssm get-parameter --name "$PARAM_NAME" --query "Parameter.Value" --output text 2>/dev/null || echo "NOT_SET")

echo "Updating Parameter Store:"
echo "  Parameter: $PARAM_NAME"
echo "  Current value: $CURRENT"
echo "  New value: $ADAPTER_ID"
echo ""

# Update the parameter
aws ssm put-parameter \
  --name "$PARAM_NAME" \
  --type String \
  --value "$ADAPTER_ID" \
  --overwrite

echo "Parameter updated successfully."
echo ""
echo "Applications retrieving adapter ID from $PARAM_NAME will now use: $ADAPTER_ID"
echo "No application redeployment is required."
