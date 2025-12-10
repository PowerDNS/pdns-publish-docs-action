# pdns-publish-docs-action

This repo contains a GitHub Action to publish mkdocs-style docs to S3, including managing the version
information so that multiple copies of the docs can be maintained.

## Usage

```yaml
- uses: pdns/pdns-publish-docs-action@v1
  with:
    # The AWS access key id to use
    aws_access_key_id: ''
    
    # The AWS secret access key to use
    aws_secret_access_key: ''
    
    # The AWS region to use
    aws_region: ''
    
    # The name of the S3 bucket to use
    aws_s3_bucket: ''
    
    # The CloudFront distribution id to invalidate (this ensures that the new docs are immediately available)
    aws_cloudfront_distribution_id: ''

    # The mkdocs.yml file to use (this can include a path). It is relative to the root of the repo.
    mkdocs_file: ''
    
    # The git ref to use for versioning. This should be a semver-style string, but it's not mandatory.
    version_string: ''
    
    # The directory containing the mkdocs docs to publish. This is relative to the root of the repo.
    bucket_dir: "docs.powerdns.com"
    
    # The subdirectory under bucket_dir to publish to, i.e. bucket_dir/bucket_subdir will be the path used. The action assumes that the path exists.
    bucket_subdir: ''
```
All parameters are required except for `bucket_dir`.

The action will build the mkdocs docs and publish them to S3, then invalidate the CloudFront distribution. 
The versions.json file will be updated to include the new version. The "latest" version will be updated to point to the
new version if that is the most recent, according to semver rules.