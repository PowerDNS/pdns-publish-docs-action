#!/bin/sh

# Documentation Building Script - designed to be run as a GitHub Action
#
# This script makes PowerDNS HTML documentation ready for copying to S3, then copies it using
# the publish_to_s3.sh helper script.
# It also sets the correct "latest" version information in the bucket subdir.
#
# Environment Variables Required:
# - INPUT_AWS_ACCESS_KEY_ID: The AWS access key ID
# - INPUT_AWS_SECRET_ACCESS_KEY: The AWS secret access key
# - INPUT_AWS_REGION: The AWS region where resources are located
# - INPUT_AWS_S3_BUCKET: The name of the S3 bucket for documentation
# - INPUT_AWS_CLOUDFRONT_DISTRIBUTION_ID: The CloudFront distribution ID
# - INPUT_MKDOCS_FILE: The location of the mkdocs.yml file
# - INPUT_VERSION_STRING: The version string for the docs. Should be a semver-style version string
# - INPUT_BUCKET_SUBDIR: The sub directory of INPUT_BUCKET_DIR to put the built documentation into
# Optional:
# - INPUT_BUCKET_DIR: The parent directory of the documentation bucket to put the built documentation
#
# Usage:
# ./mkdocs.sh

set -e  # Exit immediately if a command exits with a non-zero status

valid_input=1

if [ -z "$INPUT_AWS_ACCESS_KEY_ID" ]
then
  echo "Environment variable INPUT_AWS_ACCESS_KEY_ID must be set"
  valid_input=0
fi
if [ -z "$INPUT_AWS_SECRET_ACCESS_KEY" ]
then
  echo "Environment variable INPUT_AWS_SECRET_ACCESS_KEY must be set"
  valid_input=0
fi
if [ -z "$INPUT_AWS_REGION" ]
then
  echo "Environment variable INPUT_AWS_REGION must be set"
  valid_input=0
fi
if [ -z "$INPUT_AWS_S3_BUCKET" ]
then
  echo "Environment variable INPUT_AWS_S3_BUCKET must be set"
  valid_input=0
fi
if [ -z "$INPUT_AWS_CLOUDFRONT_DISTRIBUTION_ID" ]
then
  echo "Environment variable INPUT_AWS_CLOUDFRONT_DISTRIBUTION_ID must be set"
  valid_input=0
fi
if [ -z "$INPUT_MKDOCS_FILE" ]
then
  echo "Environment variable INPUT_MKDOCS_FILE must be set"
  valid_input=0
fi
if [ -z "$INPUT_VERSION_STRING" ]
then
  echo "Environment variable INPUT_VERSION_STRING must be set"
  valid_input=0
fi
if [ -z "$INPUT_BUCKET_SUBDIR" ]
then
  echo "Environment variable INPUT_BUCKET_SUBDIR must be set"
  valid_input=0
fi

if [ -z "$INPUT_BUCKET_DIR" ]
then
  INPUT_BUCKET_DIR="docs.powerdns.com"
  valid_input=0
fi

if [ $valid_input -eq 0 ]
then
  exit 1
fi

export AWS_ACCESS_KEY_ID="$INPUT_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$INPUT_AWS_SECRET_ACCESS_KEY"
export AWS_REGION="$INPUT_AWS_REGION"
export AWS_S3_BUCKET_DOCS="$INPUT_AWS_S3_BUCKET"
export AWS_CLOUDFRONT_DISTRIBUTION_ID_DOCS="$INPUT_AWS_CLOUDFRONT_DISTRIBUTION_ID"

mkdocs_file="$INPUT_MKDOCS_FILE"
version="$INPUT_VERSION_STRING"
subdir="$INPUT_BUCKET_SUBDIR"

publish_script="/scripts/publish_to_s3.sh"

# Prep temporary output location
mkdir -p "${PWD}/output/${version}"

mkdocs  build -f "$mkdocs_file" -d "${PWD}/output/${version}"

latestVersion=$(aws s3 ls s3://"${AWS_S3_BUCKET_DOCS}"/"${INPUT_BUCKET_DIR}"/"$subdir"/ | awk '{print $2}' | grep -v latest | awk -F '/' '/\// {print $1}' | sort -V | tail -1)

if [ "$latestVersion" = "" ]; then
  latestVersion="0"
fi

echo "Publishing version $version. Latest version already in S3 is $latestVersion"

$publish_script "${PWD}/output/${version}" "$subdir/${version}"

if [ "$(echo "$latestVersion" "$version" | awk '{if ($1 < $2) print 1;}')" != 0 ]; then
  echo "This version is newer than the latest version in S3, publishing this version to latest"
  $publish_script "${PWD}/output/${version}" "$subdir/latest"
  latestVersion="$version"
fi

# Build versions.json
versionsData=$(echo "[]" | jq)

while read -r docsVersion; do
  if [ "$docsVersion" != "" ] && [ "$docsVersion" != "latest" ]; then
    if [ "$docsVersion" = "$latestVersion" ]; then
      versionsData=$(echo "$versionsData" | jq ". += [{\"title\": \"${docsVersion}\", \"version\": \"${latestVersion}\", \"aliases\": [\"latest\"]}]")
    else
      versionsData=$(echo "$versionsData" | jq ". += [{\"title\": \"${docsVersion}\", \"version\": \"${docsVersion}\", \"aliases\": []}]")
    fi
  fi
done < <(aws s3 ls s3://"${AWS_S3_BUCKET_DOCS}"/docs.powerdns.com/"$subdir"/ | awk '{print $2}' | awk -F '/' '/\// {print $1}')

echo "${versionsData}" > "${PWD}/output/versions.json"

$publish_script "${PWD}/output/versions.json" "$subdir"

$publish_script "${PWD}/doc/html/index.html" "$subdir"

exit 0
