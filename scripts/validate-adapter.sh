#!/bin/bash
# Validate an adapter by running a test document through Amazon Textract.
#
# Use this script after an adapter copy completes (via AWS Support ticket)
# to verify extraction accuracy matches your baseline.
#
# Usage:
#   ./validate-adapter.sh --adapter-id <id> --version <ver> --bucket <bucket> --document <key> --query <question>
#
# Example:
#   ./validate-adapter.sh --adapter-id "xxxxxx" --version 1 \
#     --bucket "amzn-s3-demo-destination-bucket-xx" \
#     --document "test-claim-form.pdf" \
#     --query "What is the policy number?"

set -euo pipefail

# Parse arguments
ADAPTER_ID=""
ADAPTER_VERSION="1"
BUCKET=""
DOCUMENT=""
QUERY_TEXT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --adapter-id) ADAPTER_ID="$2"; shift 2 ;;
    --version) ADAPTER_VERSION="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --document) DOCUMENT="$2"; shift 2 ;;
    --query) QUERY_TEXT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ADAPTER_ID" || -z "$BUCKET" || -z "$DOCUMENT" || -z "$QUERY_TEXT" ]]; then
  echo "Error: --adapter-id, --bucket, --document, and --query are required"
  echo "Usage: ./validate-adapter.sh --adapter-id <id> --version <ver> --bucket <bucket> --document <key> --query <question>"
  exit 1
fi

echo "Validating adapter: $ADAPTER_ID (version: $ADAPTER_VERSION)"
echo "Test document: s3://$BUCKET/$DOCUMENT"
echo "Query: $QUERY_TEXT"
echo ""

# Run AnalyzeDocument with the adapter
RESPONSE=$(aws textract analyze-document \
  --document "{\"S3Object\":{\"Bucket\":\"$BUCKET\",\"Name\":\"$DOCUMENT\"}}" \
  --feature-types QUERIES \
  --adapters-config "{\"Adapters\":[{\"AdapterId\":\"$ADAPTER_ID\",\"Version\":\"$ADAPTER_VERSION\",\"Pages\":[\"*\"]}]}" \
  --queries-config "{\"Queries\":[{\"Text\":\"$QUERY_TEXT\",\"Alias\":\"VALIDATION_QUERY\",\"Pages\":[\"*\"]}]}" \
  --output json)

if [[ $? -ne 0 ]]; then
  echo "Error: AnalyzeDocument call failed"
  exit 1
fi

# Display results - show both the query and its answer
echo "Results:"
echo "$RESPONSE" | jq -r '
  .Blocks[] |
  if .BlockType == "QUERY" then
    "  Query: \(.Query.Text)"
  elif .BlockType == "QUERY_RESULT" then
    "  Answer: \(.Text) (confidence: \(.Confidence | tostring | .[0:5])%)"
  else empty end
'

echo ""
echo "Validation complete. Compare results against your expected baseline."
echo "If accuracy meets your threshold, proceed with updating Parameter Store."
