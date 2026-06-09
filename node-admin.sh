#!/bin/sh

if [ "$#" -lt 1 ]; then
    echo "Usage node-admin.sh <consumer|provider> <bootstrap_command>. For help use node-admin.sh consumer|provider --help"
    exit 1
fi

command='node src/index.js'

bootstrap_env='--load-env=./.env.bootstrap'
final_command="$command ${@:2} $bootstrap_env"


docker compose run --rm -it dpi-node-$1 sh -c "${final_command}"
