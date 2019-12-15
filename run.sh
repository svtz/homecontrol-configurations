#!/bin/bash

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

remove_container () {
    echo "Removing $1..."
    containerId=$(docker ps -a -q --filter name=$1)
    if [ -z "containerId" ]
    then
        echo "No such container, skipped"
    else
        docker kill $containerId > /dev/null
        docker rm $containerId > /dev/null
        echo "OK"
    fi
}


remove_container "homecontrol_noolite"
remove_container "homecontrol_controller"
remove_container "homecontrol_configstore"
remove_container "homecontrol_rabbitmq"

echo "Recreating network homecontrol..."
networkId=$(docker network ls -q --filter name=homecontrol)
[ ! -z "$networkId" ] && docker network rm $networkId > /dev/null
docker network create homecontrol > /dev/null
echo "OK"

printf "Starting homecontrol_rabbitmq. This will take a few minutes..."
docker pull svtz/homecontrol:rabbitmq-arm32v7 > /dev/null
printf "."
docker run --detach                   \
    -p 4369:4369                      \
    -p 5671:5671                      \
    -p 5672:5672                      \
    -p 25672:25672                    \
    --name homecontrol_rabbitmq       \
    --restart=always                  \
    svtz/homecontrol:rabbitmq-arm32v7 > /dev/null
for tick in (1..120)
do
    printf "."
    sleep 1s
done
printf "\nOK"

echo "Starting homecontrol_configstore..."
docker pull svtz/homecontrol:config-store-arm32v7 > /dev/null
docker run --detach                       \
    --volume conf:/app/conf               \
    --name homecontrol_configstore        \
    --restart=always                      \
    svtz/homecontrol:config-store-arm32v7 > /dev/null
echo "OK"

echo "Starting homecontrol_controller..."
docker pull svtz/homecontrol:controller-arm32v7 > /dev/null
docker run --detach                     \
    --name homecontrol_controller       \
    --restart=always                    \
    svtz/homecontrol:controller-arm32v7 > /dev/null
echo "OK"

echo "Starting homecontrol_noolite..."
docker pull svtz/homecontrol:noolite-arm32v7 > /dev/null
docker run --detach                  \
    --name homecontrol_noolite       \
    --restart=always                 \
    --privileged                     \
    -v /dev/bus/usb:/dev/bus/usb     \
    svtz/homecontrol:noolite-arm32v7 > /dev/null
echo "OK"

echo "COMPLETE"