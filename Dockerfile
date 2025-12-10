FROM registry.open-xchange.com/cc-utils/docs-manager:2

RUN pip install mkdocs-swagger-ui-tag && apk add curl aws-cli

RUN mkdir /scripts
COPY mkdocs.sh publish_to_s3.sh /scripts/

ENTRYPOINT ["sh", "/scripts/mkdocs.sh"]