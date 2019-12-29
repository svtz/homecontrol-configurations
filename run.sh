#!/bin/bash
# exit when any command fails
set -e

remove_container () {
    echo -n "Removing $1..."
    containerId=$(docker ps -a -q --filter name=$1)

    if [ -z "$containerId" ]
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
echo -n "Recreating network homecontrol..."
networkId=$(docker network ls -q --filter name=homecontrol)
[ ! -z "$networkId" ] && docker network rm $networkId > /dev/null
docker network create homecontrol > /dev/null
echo "OK"

echo -n "Starting homecontrol_rabbitmq. This will take a few minutes..."
docker pull svtz/homecontrol:rabbitmq-arm32v7 > /dev/null
echo -n "."
docker run --detach \
    -p 4369:4369 \
    -p 5671:5671 \
    -p 5672:5672 \
    -p 25672:25672 \
    --name homecontrol_rabbitmq \
    --restart=always \
    --net homecontrol \
    svtz/homecontrol:rabbitmq-arm32v7 > /dev/null

for tick in {1..120}
do
    echo -n "."
    sleep 1s
done
echo "OK"

echo -n "Starting homecontrol_configstore..."
docker pull svtz/homecontrol:config-store-arm32v7 > /dev/null
docker run --detach \
    --volume /home/svtz/homecontrol/conf:/app/conf \
    --name homecontrol_configstore \
    --restart=always \
    --net homecontrol \
    svtz/homecontrol:config-store-arm32v7 > /dev/null
echo "OK"

echo -n "Starting homecontrol_controller..."
docker pull svtz/homecontrol:controller-arm32v7 > /dev/null
docker run --detach \
    --name homecontrol_controller \
    --restart=always \
    --net homecontrol \
    svtz/homecontrol:controller-arm32v7 > /dev/null
echo "OK"

echo -n "Starting homecontrol_noolite..."
docker pull svtz/homecontrol:noolite-arm32v7 > /dev/null
docker run --detach \
    --name homecontrol_noolite \
    --restart=always \
    --privileged \
    --volume /dev/bus/usb:/dev/bus/usb \
    --net homecontrol \
    svtz/homecontrol:noolite-arm32v7 > /dev/null
echo "OK"

echo "COMPLETE"
