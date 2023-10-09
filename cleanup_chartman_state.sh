#!/bin/bash

# remove everything that was created by docker compose, it is good enough for current issue
text_to_match="com.docker.compose.project.config_files"

container_ids=$(docker ps -a --format "{{.ID}} {{.Labels}}" | grep "$text_to_match" | awk '{print $1}')
echo $container_ids

# Stop and remove each container
for container_id in $container_ids
do
    echo "Stopping and removing container $container_id..."
    docker stop "$container_id"
    docker rm "$container_id"
done
