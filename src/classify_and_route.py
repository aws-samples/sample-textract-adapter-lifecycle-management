"""
Document pre-classification and adapter routing for Amazon Textract.

Amazon Textract supports one adapter per page per feature type in a single API call.
This module provides a configurable routing mechanism that scans document content
for version-specific markers and retrieves the corresponding adapter ID from
AWS Systems Manager Parameter Store.
"""

import re
import boto3

# Define adapter routing rules as configuration.
# Each entry maps a regex pattern (matching form markers in the document text)
# to a Parameter Store path containing the adapter ID for that document type.
ADAPTER_ROUTES = [
    {"pattern": r"ABC[-\s]?214", "param": "/textract/adapters/abc214/id"},
    {"pattern": r"ABC[-\s]?2\b", "param": "/textract/adapters/abc2/id"},
    {"pattern": r"ABC[-\s]?3\b", "param": "/textract/adapters/abc3/id"},
    {"pattern": r"XYZ[-\s]?86", "param": "/textract/adapters/xyz86/id"},
]
DEFAULT_ADAPTER_PARAM = "/textract/adapters/default/id"


def classify_and_get_adapter(raw_text: str) -> str:
    """Match document text against known form markers and return the adapter ID.

    Scans raw_text for version-specific markers (form titles, identifiers,
    field labels) and retrieves the corresponding adapter ID from Parameter Store.

    The raw_text input can come from a lightweight DetectDocumentText call on
    the first page, from a PDF text extraction library, or from metadata
    already available in your ingestion pipeline.

    Args:
        raw_text: Extracted text content from the document.

    Returns:
        The adapter ID string retrieved from Parameter Store.
    """
    ssm = boto3.client("ssm")

    param_name = DEFAULT_ADAPTER_PARAM
    for route in ADAPTER_ROUTES:
        if re.search(route["pattern"], raw_text, re.IGNORECASE):
            param_name = route["param"]
            break

    return ssm.get_parameter(Name=param_name)["Parameter"]["Value"]
