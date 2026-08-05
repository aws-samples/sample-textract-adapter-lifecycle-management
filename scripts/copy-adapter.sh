#!/bin/bash
# Validate a copied adapter in the destination account by running test documents.
#
# After an adapter copy completes (via AWS Support ticket), use this script
# to verify extraction accuracy matches your baseline.
#
# Usage:
#   ./copy-adapter.sh --adapter-id <id> --version <ver> --bucket <bucket> --document <key>
#
# Example:
#   ./copy-adapter.sh --adapter-id "x9y8z7w6v5u4" --version 1 \
#     --bucket "amzn-s3-demo-destination-bucket" --document "test-claim-form.pdf"

set -euo pipefail

# Parse arguments
ADAPTER_ID=""
ADAPTER_VERSION="1"
BUCKET=""
DOCUMENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --adapter-id) ADAPTER_ID="$2"; shift 2 ;;
    --version) ADAPTER_VERSION="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --document) DOCUMENT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ADAPTER_ID" || -z "$BUCKET" || -z "$DOCUMENT" ]]; then
  echo "Error: --adapter-id, --bucket, and --document are required"
  echo "Usage: ./copy-adapter.sh --adapter-id <id> --version <ver> --bucket <bucket> --document <key>"
  exit 1
fi

echo "Validating adapter: $ADAPTER_ID (version: $ADAPTER_VERSION)"
echo "Test document: s3://$BUCKET/$DOCUMENT"
echo ""

# Run AnalyzeDocument with the copied adapter
RESPONSE=$(aws textract analyze-document \
  --document "{\"S3Object\":{\"Bucket\":\"$BUCKET\",\"Name\":\"$DOCUMENT\"}}" \
  --feature-types QUERIES \
  --adapters-config "{\"Adapters\":[{\"AdapterId\":\"$ADAPTER_ID\",\"Version\":$ADAPTER_VERSION,\"Pages\":[\"*\"]}]}" \
  --queries-config '{"Queries":[{"Text":"What is the policy number?","Alias":"POLICY_NUMBER","Pages":["*"]}]}' \
  --output json)

# Check for errors
if [[ $? -ne 0 ]]; then
  echo "Error: AnalyzeDocument call failed"
  exit 1
fi

# Display query results
echo "Query Results:"
echo "$RESPONSE" | jq -r '.Blocks[] | select(.BlockType == "QUERY_RESULT") | "  \(.Query.Alias // "N/A"): \(.Text // "N/A") (confidence: \(.Confidence // 0)%)"'

echo ""
echo "Validation complete. Compare results against your expected baseline."
echo "If accuracy meets your threshold, proceed with updating Parameter Store."
