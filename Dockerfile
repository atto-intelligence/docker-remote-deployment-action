FROM docker/compose:1.29.2

LABEL 'name'='Docker Remote Deployment Action'
LABEL 'com.github.actions.name'='Docker Deployment'
LABEL 'com.github.actions.description'='supports docker-compose and Docker Swarm deployments'
LABEL 'com.github.actions.icon'='send'
LABEL 'com.github.actions.color'='green'

RUN apk --no-cache add openssh-client make bash jq

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["bash", "/docker-entrypoint.sh"]
