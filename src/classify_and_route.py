"""
Document pre-classification and adapter routing for Amazon Textract.

Amazon Textract supports one adapter per AnalyzeDocument API call per feature type.
This module provides a lightweight text-based classification step that scans document
content for version-specific markers and routes to the appropriate adapter.
"""

import re
import boto3

ssm = boto3.client("ssm")


def classify_and_get_adapter(raw_text: str) -> str:
    """Route document to correct adapter based on form markers.

    Scans the raw text for version-specific markers (form titles, version
    identifiers, field labels) and retrieves the corresponding adapter ID
    from AWS Systems Manager Parameter Store.

    Args:
        raw_text: Extracted text content from the document (e.g., from
                  Amazon Textract DetectDocumentText or a PDF parser).

    Returns:
        The adapter ID string retrieved from Parameter Store.
    """
    if re.search(r"CLAIM FORM.*VERSION 3", raw_text, re.IGNORECASE):
        param_name = "/textract/adapters/claim-form-v3/id"
    elif re.search(r"CLAIM FORM.*VERSION 2", raw_text, re.IGNORECASE):
        param_name = "/textract/adapters/claim-form-v2/id"
    elif re.search(r"APPLICATION FORM", raw_text, re.IGNORECASE):
        param_name = "/textract/adapters/application-form/id"
    else:
        param_name = "/textract/adapters/default/id"

    # Retrieve adapter ID from Parameter Store
    response = ssm.get_parameter(Name=param_name)
    return response["Parameter"]["Value"]
