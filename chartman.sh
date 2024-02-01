#!/bin/bash

### Don't modify this script. If you encountered any problems, please contact P24 Team

dockerImage=${CHARTMAN_DOCKER_IMAGE:-docker-registry.ds.mhie.com/chartman}
versionRequest=${CHARTMAN_VERSION:-3}
cacheTtl=${CHARTMAN_CACHE_TTL:-300}
latestTag="latest"
cacheFilePath="/tmp/chartman/request-$versionRequest"
tracesFilePath="/dev/null"

if [ "$CHARTMAN_TRACE_ENABLED" = "1" ]; then
  tracesFilePath=".chartman-traces.log"
fi

if [ "$CHARTMAN_SCRIPT_AUTOUPDATE" = "1" ]; then
  CHARTMAN_SCRIPT_URL="https://raw.githubusercontent.com/MHI-EMEA-DS/yais/main/chartman.sh"
  CHARTMAN_SCRIPT_LOCATION="/usr/local/bin/chartman"

  curl_output=$(curl -s "$CHARTMAN_SCRIPT_URL")
  diff_output=$(diff -q <(echo "$curl_output") "$CHARTMAN_SCRIPT_LOCATION")

  if [ $? -ne 0 ]; then
    echo "New Version of chartman script downloaded and updated"
    TMP_FILE="/tmp/chartman/$(uuidgen)"
    touch "$TMP_FILE"
    curl -s -L "$CHARTMAN_SCRIPT_URL" >> "$TMP_FILE"
    ABS_SCRIPT_PATH=$(readlink -f "$CHARTMAN_SCRIPT_LOCATION")

    echo "cp \"$TMP_FILE\" \"$ABS_SCRIPT_PATH\"" > ~/updater.sh
    echo "rm -rf \"$TMP_FILE\"" >> ~/updater.sh
    echo "exec \"$ABS_SCRIPT_PATH\" -V" >> ~/updater.sh

    chmod +x ~/updater.sh
    exec ~/updater.sh
  fi
fi

trace() {
  if [ "$CHARTMAN_TRACE_ENABLED" = "1" ]; then
    echo "$1"
    echo "$1" >> $tracesFilePath
  fi
}

check_file_modified_within_seconds() {
  file_path="$1"
  seconds_threshold="$2"

  # Check if the file exists
  if [ ! -f "$file_path" ]; then
    return 1
  fi

  current_time=$(date +%s)
  if [ "$(uname)" == "Darwin" ]; then
    file_modified_time=$(stat -f %m "$file_path")
  else
    file_modified_time=$(stat -c %Y "$file_path")
    stat -c "%Y" filename
  fi
  time_difference=$((current_time - file_modified_time))

  if [ $time_difference -le $seconds_threshold ]; then
    return 0
  else
    return 1
  fi
}

if [ ! -f "$HOME/.npmrc" ]; then
  echo "Error: .npmrc file does not exist at path $HOME/.npmrc"
  exit 1
fi

read_run_parameters() {
  runParameters="$1"

  requestedVersion=`echo "$runParameters" | sed -n 's/^.*REQUESTED_VERSION=//p'`
  latestVersion=`echo "$runParameters" | sed -n 's/^.*LATEST_VERSION=//p'`
  runDockerArgs=`echo "$runParameters" | sed -n 's/^.*DOCKER_ARGS=//p'`
}

# requested version - version in semver search format requested by user. Can be: 3.14.0, 3.x or 3.13.0-
# latest version used for getting internal arguments
# when user requested a canary version, latest version = requested canary version
resolve_run_parameters() {
  # TODO: run pull operations in parallel
  pullResult=`docker pull $dockerImage:$latestTag 2>&1`
  pullSucceed=$?
  if [ "$pullSucceed" -ne 0 ]; then
    echo $pullResult >&2
    return 1
  fi

  pullResult=`docker pull $dockerImage:$versionRequest 2>&1`
  pullSucceed=$?
  if [ "$pullSucceed" -ne 0 ]; then
    echo $pullResult >&2
    return 1
  fi

  # check for canary version. If so - latest version = canary version
  if [[ $versionRequest == *-* ]]; then
    latestVersion=$versionRequest
  else
    latestVersion=$latestTag
  fi

  trace "Fetching run parameters with version $latestVersion"

  response=`docker run --rm -e CHARTMAN_DOCKER_REGISTRY_TOKEN=$CHARTMAN_DOCKER_REGISTRY_TOKEN -v $HOME/.chartman:/root/.chartman -v $HOME/.docker:/root/.docker $dockerImage:$latestVersion internal get-run-parameters $dockerImage $versionRequest 2>&1`
  runSucceed=$?

  if [ "$runSucceed" -nq 0 ]; then
    echo $response >&2
    return 1
  fi
  latestVersion=`echo "$response" | sed -n 's/^.*chartman v\([^[:space:]]*\).*/\1/p'`
  runDockerArgs=`echo "$response" | sed -n 's/^.*DOCKER_ARGS=//p'`

  response=`docker run --rm $dockerImage:$versionRequest --version 2>&1`
  runSucceed=$?

  if [ "$runSucceed" -nq 0 ]; then
    echo $response >&2
    return 1
  fi

  requestedVersion=`echo "$response" | sed -n 's/^.*chartman v\([^[:space:]]*\).*/\1/p'`

  # write cache
  echo "DOCKER_ARGS=$runDockerArgs" > $cacheFilePath
  echo "LATEST_VERSION=$latestVersion" >> $cacheFilePath
  echo "REQUESTED_VERSION=$requestedVersion" >> $cacheFilePath

  return 0
}

trace "Docker Image: $dockerImage"
trace "Version Request: $versionRequest"
trace "Cache TTL: $cacheTtl"

dockerArgs=""

if [ "$CHARTMAN_INTERACTIVE" = "1" ]; then dockerArgs="$dockerArgs -it"; fi

# if nvidia docker runtime is installed, use it, to provide gpu info to charts
if [ -f "/usr/bin/nvidia-container-runtime" ]; then
  dockerArgs="$dockerArgs --runtime=nvidia --gpus all"
fi

mkdir -p "/tmp/chartman"

cached=false
if check_file_modified_within_seconds "$cacheFilePath" "$cacheTtl"; then
  trace "Cache parameters found $cacheFilePath"
  read_run_parameters "$(cat $cacheFilePath)"
  if [ -n "$requestedVersion" ] && [ -n "$latestVersion" ] && [ -n "$runDockerArgs" ]; then
    cached=true
  fi
fi

if [ "$cached" = false ]; then
  resolve_run_parameters_output=$(resolve_run_parameters 2>&1)
  resolve_parameters_return_code=$?

  if [ "$resolve_parameters_return_code" -ne 0 ]; then
    echo "$resolve_run_parameters_output"
    return 1
  fi

  read_run_parameters "$(cat $cacheFilePath)"
fi

if [ "$latestVersion" != "$requestedVersion" ]; then
  >&2 echo "A newer version is available: $latestVersion"
fi

trace "Version: $requestedVersion"
trace "LatestVersion: $latestVersion"
trace "Docker Args: $runDockerArgs"

resolvedArgs=$(eval echo \"$runDockerArgs\")

trace "Resolved args: $resolvedArgs"
trace "docker run --rm $dockerArgs $resolvedArgs -w $PWD $dockerImage:$requestedVersion"

docker run --rm $dockerArgs $resolvedArgs -w $PWD $dockerImage:$requestedVersion "$@"
