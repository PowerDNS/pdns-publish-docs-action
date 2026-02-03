#!/bin/sh
# shellcheck shell=busybox

# PowerDNS Documentation Publishing Script
#
# This script invalidates the CloudFront cache for a specific file or directory. This uses the AWS CLI.
#
# Environment Variables Required:
# - AWS_CLOUDFRONT_DISTRIBUTION_ID_DOCS: The CloudFront distribution ID
#
# Usage:
# ./cloudfront_invalidate.sh <--recursive> [TARGET_DIR]

set -e  # Exit immediately if a command exits with a non-zero status

# Check if AWS CLI is installed
if ! command -v aws > /dev/null 2>&1; then
    echo "AWS CLI is not installed. Please install it and try again."
    exit 1
fi

# Function to invalidate CloudFront cache
invalidate_cloudfront() {
    invalidation_path="$1"
    aws cloudfront create-invalidation --distribution-id "${AWS_CLOUDFRONT_DISTRIBUTION_ID_DOCS}" --paths "${invalidation_path}" || {
        echo "Failed to create CloudFront invalidation for ${invalidation_path}"
        exit 1
    }
}

usage() {
  echo "Usage: $0 --recursive [TARGET_DIR]"
  exit 1
}

# Main script execution
if [ "$#" -eq 0 ]; then
    usage
fi

RECURSIVE=""
target_path=""
while [ $# -gt 0 ]; do
  case $1 in
    -r|--recursive)
      RECURSIVE="*"
      shift
      ;;
  *)
    target_path="$1"
    shift
    ;;
  esac
done

if [ "$target_path" = "" ]
then
  usage
fi

target_path="$target_path""$RECURSIVE"

invalidate_cloudfront "$target_path"

exit 0
