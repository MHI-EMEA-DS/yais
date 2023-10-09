#!/bin/bash

capture_docker_info() {
    local output_file="$1"

    local container_info=$(docker ps --format "{{.ID}} {{.Names}}" | sed 's/ /:/')

    while IFS=':' read -r container_id container_name; do
        echo "Container ID: $container_id" >> "$output_file"
        echo "Container Name: $container_name" >> "$output_file"
        docker inspect "$container_id" >> "$output_file"
        echo "=======================================" >> "$output_file"
    done <<< "$container_info"

    echo "Docker container information (including 'docker inspect') saved to $output_file"
}

append_file_content() {
    local file_to_append="$1"
    local output_file="$2"

    if [ -e "$file_to_append" ]; then
        echo "Content of $file_to_append:" >> "$output_file"
        cat "$file_to_append" >> "$output_file"
        echo "=======================================" >> "$output_file"
    else
        echo "File $file_to_append does not exist." >> "$output_file"
    fi
}

output_file="chartman_state_info.txt"

> "$output_file"

capture_docker_info "$output_file"

append_file_content "/mhi/.chartman/state.json" "$output_file"
append_file_content "/mhi/sxs/.chartman/state.json" "$output_file"
