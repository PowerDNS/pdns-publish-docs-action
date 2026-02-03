#!/bin/sh
# shellcheck shell=busybox

# PowerDNS Documentation Publishing Script
#
# This script uploads documentation to an S3 bucket. This uses the AWS CLI.
# The script used to invalidate the cloudfront cache, but this is now done in a separate script.
#
# Environment Variables Required:
# - AWS_ACCESS_KEY_ID: The AWS access key ID
# - AWS_SECRET_ACCESS_KEY: The AWS secret access key
# - AWS_REGION: The AWS region where resources are located
# - AWS_S3_BUCKET_DOCS: The name of the S3 bucket for documentation
#
# Usage:
# ./publish_to_s3.sh <SOURCE_PATH> [TARGET_DIR]

set -e  # Exit immediately if a command exits with a non-zero status

# Check if AWS CLI is installed
if ! command -v aws > /dev/null 2>&1; then
    echo "AWS CLI is not installed. Please install it and try again."
    exit 1
fi

# Function to upload file or directory to S3
upload_to_s3() {
    local source_path="$1"
    local dest_dir="$2"

    if [ -d "$source_path" ]; then
      aws s3 cp --recursive "$source_path" "s3://${AWS_S3_BUCKET_DOCS}/${dest_dir}/"
    else
      aws s3 cp "$source_path" "s3://${AWS_S3_BUCKET_DOCS}/${dest_dir}/"
    fi
}

# Main function to publish to site
publish_to_site() {
    local source_path="$1"
    local target_dir="${2:-}"

    upload_to_s3 "$source_path" "$target_dir"

    echo "Published from ${source_path} to ${target_dir}"
}

# Main script execution
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <SOURCE_PATH> [TARGET_DIR]"
    exit 1
fi

source_path="$1"
target_dir="${2:-}"

publish_to_site "$source_path" "$target_dir"

exit 0
