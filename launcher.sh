#!/bin/bash

if ! [[ "$1" =~ ^(start|stop|update|dev-start)$ ]]; then
    echo "Usage: launcher COMMAND"
    echo "Commands:"
    echo "    start:       Start/initialize a stack"
    echo "    stop:        Stop a running stack"
    echo "    update:      Update stack"
    echo "    dev-start:   Start stack with dev mode"
    exit 1
fi

function start_stack() {
    echo "Starting seat-docker application..."
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml -f docker-compose.traefik.yml -f docker-compose.overload.yml up -d

    echo "Deploying additional apache2 config..."
    docker compose cp apache-realip-config/use-x-forwarded-for-as-ip.conf front:/etc/apache2/conf-enabled

    # check apache2 running
    while [ -z "$(ps aux | grep apache2 | grep -v grep)" ]; do
        echo "apache2 service might not be ready yet. Sleeping..."
        sleep 1 # wait 1 sec
    done

    echo "Start enabling module remoteip..."
    docker compose exec --user root front a2enmod remoteip

    echo "Start reloading apache2 service..."
    docker compose exec --user root front service apache2 reload
}

case $1 in
start)
    echo "starting seat stack..."
    start_stack
    ;;
stop)
    echo "stopping seat stack..."
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml -f docker-compose.traefik.yml -f docker-compose.overload.yml down
    ;;
update)
    echo "updating seat stack..."

    echo "pulling latest dockerhub images..."
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml -f docker-compose.traefik.yml pull

    echo "taking stack down..."
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml -f docker-compose.traefik.yml down

    echo "bringing stack back online..."
    start_stack

    echo "cleaning any dangling images..."
    docker image prune -f
    ;;
dev-start)
    echo "starting seat dev stack..."
    echo "deploying dev packages"
    rsync -avu --delete /mnt/ubuntu-dev-env/dev-env/active-projects/Visual\ Studio\ Code/seat-discourse/ /mnt/ubuntu-dev-env/dev-env/test-env-docker/seat-docker/packages/seat-discours
    echo "Starting seat-docker application..."
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml -f docker-compose.traefik.yml -f docker-compose.overload.yml up
    ;;
esac
