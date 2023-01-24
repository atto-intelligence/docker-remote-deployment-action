#!/bin/sh
set -eu

execute_ssh() {
  echo "Execute Over SSH: $@"
  ssh -q -t -i "$HOME/.ssh/id_rsa" \
    -o UserKnownHostsFile=/dev/null \
    -p $INPUT_REMOTE_DOCKER_PORT \
    -o StrictHostKeyChecking=no "$INPUT_REMOTE_DOCKER_HOST" "$@"
}

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
    DEPLOYMENT_COMMAND=$INPUT_DOCKER_SCRIPT_SERVICE
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

set context
echo "Create docker context"
docker context create remote --docker "host=ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_REMOTE_DOCKER_PORT"
docker context use remote

if ! [ -z "${INPUT_DOCKER_REGISTRY_USERNAME+x}" ] && ! [ -z "${INPUT_DOCKER_REGISTRY_PASSWORD+x}" ]; then
  echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: docker login"
  echo "$INPUT_DOCKER_REGISTRY_PASSWORD" | docker login -u "$INPUT_DOCKER_REGISTRY_USERNAME" --password-stdin "$INPUT_DOCKER_REGISTRY_URI"
fi

if ! [ -z "${INPUT_DOCKER_PRUNE+x}" ] && [ $INPUT_DOCKER_PRUNE = 'true' ] ; then
  yes | docker --log-level debug --host "ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_REMOTE_DOCKER_PORT" system prune -a 2>&1
fi

echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}"
${DEPLOYMENT_COMMAND} ${INPUT_ARGS} 2>&1
