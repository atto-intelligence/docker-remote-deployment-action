#!/bin/sh
set -eu

if [ -z "${INPUT_REMOTE_DOCKER_PORT+x}" ]; then
  INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "${INPUT_REMOTE_DOCKER_HOST+x}" ]; then
  echo "Input remote_docker_host is required!"
  exit 1
fi

if [ -z "${INPUT_SSH_PUBLIC_KEY+x}" ]; then
  echo "Input ssh_public_key is required!"
  exit 1
fi

if [ -z "${INPUT_SSH_PRIVATE_KEY+x}" ]; then
  echo "Input ssh_private_key is required!"
  exit 1
fi

if [ -z "${INPUT_ARGS+x}" ]; then
  echo "Input input_args is required!"
  exit 1
fi

if [ -z "${INPUT_STACK_FILE_NAME+x}" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yaml
fi

if [ -z "${INPUT_DOCKER_REGISTRY_URI+x}" ]; then
  INPUT_DOCKER_REGISTRY_URI=https://registry.hub.docker.com
fi

STACK_FILE=${INPUT_STACK_FILE_NAME}
DEPLOYMENT_COMMAND_OPTIONS=""

case $INPUT_DEPLOYMENT_MODE in
  swarm)
    DEPLOYMENT_COMMAND="docker $DEPLOYMENT_COMMAND_OPTIONS stack deploy --compose-file $STACK_FILE"
  ;;

  script)
    DEPLOYMENT_COMMAND=$INPUT_DOCKER_SCRIPT
  ;;

  *)
    INPUT_DEPLOYMENT_MODE="docker-compose"
    DEPLOYMENT_COMMAND="docker-compose -f $STACK_FILE $DEPLOYMENT_COMMAND_OPTIONS"
  ;;
esac


SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

echo "Registering SSH keys..."
mkdir -p ~/.ssh

printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
printf '%s\n' "$INPUT_SSH_PUBLIC_KEY" > ~/.ssh/id_rsa.pub

chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub

eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

echo "Add known hosts"
ssh-keyscan -p $INPUT_REMOTE_DOCKER_PORT "$SSH_HOST" >> ~/.ssh/known_hosts
ssh-keyscan -p $INPUT_REMOTE_DOCKER_PORT "$SSH_HOST" >> /etc/ssh/ssh_known_hosts

echo "Create docker context"
docker context ls
docker context create remote --docker "host=ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_REMOTE_DOCKER_PORT" || true
docker context use remote

echo "$INPUT_DOCKER_REGISTRY_TOKEN" >> ~/.ssh/token.txt
scp ~/.ssh/token.txt docker@172.16.0.64:/home/docker

if ! [ -z "${INPUT_DOCKER_REGISTRY_USERNAME+x}" ] && ! [ -z "${INPUT_DOCKER_REGISTRY_TOKEN+x}" ]; then
  echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: docker login"
  echo "$INPUT_DOCKER_REGISTRY_TOKEN" | docker login -u "$INPUT_DOCKER_REGISTRY_USERNAME" --password-stdin "$INPUT_DOCKER_REGISTRY_URI"
fi

echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}"
${DEPLOYMENT_COMMAND} ${INPUT_ARGS} 2>&1
