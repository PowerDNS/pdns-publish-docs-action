FROM registry.open-xchange.com/cc-utils/docs-manager:2

RUN pip install --no-cache-dir mkdocs-swagger-ui-tag && apk add --no-cache curl aws-cli

COPY mkdocs.sh publish_to_s3.sh index.html /scripts/

ENTRYPOINT ["/scripts/mkdocs.sh"]
