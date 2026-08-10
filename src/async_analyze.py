"""
Asynchronous Amazon Textract StartDocumentAnalysis with Custom Queries adapter.

Use this pattern for multi-page PDFs or documents over 5 MB. The workflow is:
1. Upload document to S3
2. Call StartDocumentAnalysis
3. Receive completion notification via SNS/SQS
4. Call GetDocumentAnalysis to retrieve results
"""

import time
import boto3


def start_async_analysis(
    bucket: str,
    document_key: str,
    adapter_id: str,
    output_bucket: str,
    output_prefix: str = "textract-results/",
    adapter_version: int = 1,
    queries: list[dict] = None,
    sns_topic_arn: str = None,
    sns_role_arn: str = None,
) -> str:
    """Start an asynchronous document analysis job with a Custom Queries adapter.

    Args:
        bucket: S3 bucket name containing the document.
        document_key: S3 object key of the document.
        adapter_id: Amazon Textract adapter ID.
        output_bucket: S3 bucket for storing results.
        output_prefix: S3 prefix for results (default: "textract-results/").
        adapter_version: Adapter version number (default: 1).
        queries: List of query dicts with 'Text' and 'Alias' keys.
        sns_topic_arn: Optional SNS topic ARN for completion notifications.
        sns_role_arn: Optional IAM role ARN for SNS publishing.

    Returns:
        The JobId string for the async analysis job.
    """
    textract = boto3.client("textract")

    if queries is None:
        queries = [
            {"Text": "What is the policy number?", "Alias": "POLICY_NUMBER"},
            {"Text": "What is the effective date?", "Alias": "EFFECTIVE_DATE"},
        ]

    params = {
        "DocumentLocation": {
            "S3Object": {"Bucket": bucket, "Name": document_key}
        },
        "FeatureTypes": ["QUERIES"],
        "AdaptersConfig": {
            "Adapters": [
                {
                    "AdapterId": adapter_id,
                    "Version": str(adapter_version),
                    "Pages": ["*"],
                }
            ]
        },
        "QueriesConfig": {"Queries": queries},
        "OutputConfig": {"S3Bucket": output_bucket, "S3Prefix": output_prefix},
    }

    # Add SNS notification if provided
    if sns_topic_arn and sns_role_arn:
        params["NotificationChannel"] = {
            "SNSTopicArn": sns_topic_arn,
            "RoleArn": sns_role_arn,
        }

    response = textract.start_document_analysis(**params)
    return response["JobId"]


def get_analysis_results(job_id: str, max_wait_seconds: int = 300) -> dict:
    """Poll for and retrieve async analysis results.

    Args:
        job_id: The JobId returned from StartDocumentAnalysis.
        max_wait_seconds: Maximum time to wait for completion (default: 300s).

    Returns:
        The full GetDocumentAnalysis API response.

    Raises:
        TimeoutError: If the job does not complete within max_wait_seconds.
        RuntimeError: If the job fails.
    """
    textract = boto3.client("textract")
    elapsed = 0
    interval = 5

    while elapsed < max_wait_seconds:
        response = textract.get_document_analysis(JobId=job_id)
        status = response["JobStatus"]

        if status == "SUCCEEDED":
            return response
        elif status == "FAILED":
            raise RuntimeError(
                f"Document analysis failed: {response.get('StatusMessage', 'Unknown error')}"
            )

        time.sleep(interval)
        elapsed += interval

    raise TimeoutError(
        f"Job {job_id} did not complete within {max_wait_seconds} seconds"
    )


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 5:
        print(
            "Usage: python async_analyze.py <bucket> <key> <adapter_id> <output_bucket>"
        )
        sys.exit(1)

    job_id = start_async_analysis(
        bucket=sys.argv[1],
        document_key=sys.argv[2],
        adapter_id=sys.argv[3],
        output_bucket=sys.argv[4],
    )
    print(f"Started async job: {job_id}")

    print("Waiting for results...")
    result = get_analysis_results(job_id)

    for block in result.get("Blocks", []):
        if block["BlockType"] == "QUERY_RESULT":
            print(f"{block.get('Text', 'N/A')}")
