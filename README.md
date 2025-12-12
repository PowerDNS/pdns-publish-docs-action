# pdns-publish-docs-action

This repo contains a GitHub Action to publish mkdocs-style docs to S3, including managing the version
information so that multiple copies of the docs can be maintained.

## Usage

```yaml
- uses: PowerDNS/pdns-publish-docs-action@v1
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

    # The location of the mkdocs.yml file - required if build_docs is true
    mkdocs_file: ''
    
    # The version of the docs. Should be a semver-style version string. Required if version_control is true
    version_string: ''
    
    # The directory of the documentation bucket to copy the documentation to
    bucket_dir: ''docs.powerdns.com''
    
    # The sub directory (under bucket_dir) of the documentation bucket to copy the documentation to. Only allowed if bucket_dir is not empty.
    bucket_subdir: ''

    # Whether to build the docs using mkdocs, or just use an existing directory with the built docs in. If false, you must provide docs_dir input
    build_docs: 'true'
    
    # The location of an existing directory containing the built docs to be copied to S3 - required if build_docs is false
    docs_dir: ''
    
    # Whether to create multiple versions of the documentation in subdirectories and a versions.json file at the root. Must provide a version_str
    version_control: 'true'
```
All parameters are required except for `bucket_dir`.

The action will build the mkdocs docs and publish them to S3, then invalidate the CloudFront distribution. 
The versions.json file will be updated to include the new version. The "latest" version will be updated to point to the
new version if that is the most recent, according to semver rules.

## Testing

The CI for this action will push some test docs to a test bucket.

You can see the results for the first CI step here: [](https://d26lzo65kaqv8z.cloudfront.net/testdocs/) or [](https://d26lzo65kaqv8z.cloudfront.net/testdocs/latest/)

Your branch or tag should be reflected in the URL along with the version number, and previous versions.
The "latest" version should always point to the most recent version (assuming semver rules). However, if
you're just testing a branch, that probably won't update the latest link.

The second CI step results can be found here: [](https://d26lzo65kaqv8z.cloudfront.net/testdocs-noversion/)

The third CI step results can be found here: [](https://d3qblx438jamtm.cloudfront.net/index.html)
