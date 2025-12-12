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
# - INPUT_VERSION_STRING: The version string for the docs. Should be a semver-style version string
# Conditionally required:
# - INPUT_MKDOCS_FILE: The location of the mkdocs.yml file (only required if INPUT_BUILD_DOCS is true)
# - INPUT_DOCS_DIR: The location of the pre-built docs (only required if INPUT_BUILD_DOCS is false)
# Optional:
# - INPUT_BUCKET_SUBDIR: The sub directory of INPUT_BUCKET_DIR to put the built documentation into (default is empty)
# - INPUT_BUCKET_DIR: The directory of the documentation bucket to put the built documentation (has a default)
# - INPUT_BUILD_DOCS: Whether to build the docs with mkdocs before publishing (defaults to true)
# - INPUT_VERSION_CONTROL: Whether to implement the version.json and version history/latest functionality (defaults to true)
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
if [ -z "$INPUT_MKDOCS_FILE" ] && [ "$INPUT_BUILD_DOCS" = "true" ]
then
  echo "Environment variable INPUT_MKDOCS_FILE must be set since INPUT_BUILD_DOCS is true"
  valid_input=0
fi
if [ -z "$INPUT_DOCS_DIR" ] && [ "$INPUT_BUILD_DOCS" != "true" ]
then
  echo "Environment variable INPUT_DOCS_DIR must be set since INPUT_BUILD_DOCS is not true"
  valid_input=0
fi
if [ -z "$INPUT_VERSION_STRING" ] && [ "$INPUT_VERSION_CONTROL" = "true" ]
then
  echo "Environment variable INPUT_VERSION_STRING must be set when INPUT_VERSION_CONTROL is true"
  valid_input=0
fi
if [ -n "$INPUT_BUCKET_SUBDIR" ] && [ -z "$INPUT_BUCKET_DIR" ]
then
  echo "Environment variable INPUT_BUCKET_SUBDIR cannot be set when INPUT_BUCKET_DIR is not"
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

mkdocs_file="${INPUT_MKDOCS_FILE}"
version="${INPUT_VERSION_STRING}"
subdir="${INPUT_BUCKET_SUBDIR}"

publish_script="/scripts/publish_to_s3.sh"

docs_dir=""
if [ "${INPUT_BUILD_DOCS}" = "true" ]
then
  if [ "${INPUT_VERSION_CONTROL}" = "true" ]
  then
    docs_dir="${PWD}/output/${version}"
  else
    docs_dir="${PWD}/output"
  fi
  # Prep temporary output location
  mkdir -p "${docs_dir}"

  mkdocs  build -f "$mkdocs_file" -d "${docs_dir}"
else
  docs_dir="${INPUT_DOCS_DIR}"
fi

if [ "${INPUT_VERSION_CONTROL}" = "true" ]
then
  latestVersion=$(aws s3 ls s3://"${AWS_S3_BUCKET_DOCS}"/"${INPUT_BUCKET_DIR}${subdir:+/}${subdir}"/ | awk '{print $2}' | grep -v latest | awk -F '/' '/\// {print $1}' | sort -V | tail -1)

  if [ "$latestVersion" = "" ]; then
    latestVersion="0"
  fi

  echo "Publishing version $version. Latest version already in S3 is $latestVersion"
fi

echo "publish_to_s3 ${docs_dir} ${INPUT_BUCKET_DIR}${subdir:+/}${subdir}${version:+/}${version}"
$publish_script "${docs_dir}" "${INPUT_BUCKET_DIR}${subdir:+/}${subdir}${version:+/}${version}"

if [ "${INPUT_VERSION_CONTROL}" = "true" ] && [ "$(echo "$latestVersion" "$version" | awk '{if ($1 < $2) print 1;}')" != 0 ]; then
  echo "This version is newer than the latest version in S3, publishing this version to latest"
  $publish_script "${docs_dir}" "${subdir}${subdir:+/}latest"
  latestVersion="$version"

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
  done < <(aws s3 ls s3://"${AWS_S3_BUCKET_DOCS}"/"${INPUT_BUCKET_DIR}${subdir:+/}${subdir}"/ | awk '{print $2}' | awk -F '/' '/\// {print $1}')

  echo "${versionsData}" > "${PWD}/output/versions.json"

  $publish_script "${PWD}/output/versions.json" "${INPUT_BUCKET_DIR}${subdir:+/}${subdir}"

  $publish_script "/scripts/index.html" "${INPUT_BUCKET_DIR}${subdir:+/}${subdir}"

fi

exit 0
