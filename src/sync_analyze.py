"""
Synchronous Amazon Textract AnalyzeDocument with Custom Queries adapter.

Use this pattern for single-page documents or documents under 5 MB.
"""

import boto3


def analyze_document_sync(
    bucket: str,
    document_key: str,
    adapter_id: str,
    adapter_version: int = 1,
    queries: list[dict] = None,
) -> dict:
    """Analyze a document synchronously using a Custom Queries adapter.

    Args:
        bucket: S3 bucket name containing the document.
        document_key: S3 object key of the document.
        adapter_id: Amazon Textract adapter ID.
        adapter_version: Adapter version number (default: 1).
        queries: List of query dicts with 'Text', 'Alias', and optional 'Pages' keys.

    Returns:
        The full AnalyzeDocument API response.
    """
    textract = boto3.client("textract")

    if queries is None:
        queries = [
            {"Text": "What is the policy number?", "Alias": "POLICY_NUMBER", "Pages": ["*"]},
            {"Text": "What is the claim date?", "Alias": "CLAIM_DATE", "Pages": ["*"]},
            {"Text": "What is the claimant name?", "Alias": "CLAIMANT_NAME", "Pages": ["*"]},
        ]

    response = textract.analyze_document(
        Document={"S3Object": {"Bucket": bucket, "Name": document_key}},
        FeatureTypes=["QUERIES"],
        AdaptersConfig={
            "Adapters": [
                {
                    "AdapterId": adapter_id,
                    "Version": adapter_version,
                    "Pages": ["*"],
                }
            ]
        },
        QueriesConfig={"Queries": queries},
    )

    return response


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 4:
        print("Usage: python sync_analyze.py <bucket> <key> <adapter_id>")
        sys.exit(1)

    result = analyze_document_sync(
        bucket=sys.argv[1],
        document_key=sys.argv[2],
        adapter_id=sys.argv[3],
    )

    # Print query results
    for block in result.get("Blocks", []):
        if block["BlockType"] == "QUERY_RESULT":
            print(f"{block.get('Text', 'N/A')}")
