#!/bin/bash

### Don't modify this script. If you encountered any problems, please contact CM Team

dockerImage=${CHARTMAN_DOCKER_IMAGE:-docker-registry.ds.mhie.com/chartman}
versionRequest=${CHARTMAN_VERSION:-3.x}
cacheTtl=${CHARTMAN_CACHE_TTL:-300}
minimumRunVersion="3.5.0"
cacheFilePath="/tmp/chartman/request-$versionRequest"
latestFilePath="/tmp/chartman/latest"
tracesFilePath="/dev/null"

if [ "$CHARTMAN_TRACE_ENABLED" = "1" ]; then
  tracesFilePath=".chartman-traces.log"
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
  file_modified_time=$(stat -c %Y "$file_path")
  time_difference=$((current_time - file_modified_time))

  if [ $time_difference -le $seconds_threshold ]; then
    return 0
  else
    if [ -s "$file_path"]; then
      return 0
    fi
    return 1
  fi
}

read_run_parameters() {
  runParameters="$1"

  requestedVersion=`echo "$runParameters" | sed -n 's/^.*REQUESTED_VERSION=//p'`
  echo $requestedVersion
  latestVersion=`echo "$runParameters" | sed -n 's/^.*LATEST_VERSION=//p'`
  runDockerArgs=`echo "$runParameters" | sed -n 's/^.*DOCKER_ARGS=//p'`
}

fetch_run_parameters() {
  version="$1"

  trace "Fetching run parameters with version $version"

  runParametersOutput=`docker run --rm -v $HOME/.chartman:/root/.chartman -v $HOME/.docker:/root/.docker $dockerImage:$version internal get-run-parameters --image-url $dockerImage $versionRequest 2>>"$tracesFilePath"`
  runSucceed=$?

  if [ "$runSucceed" -eq 0 ]; then
    read_run_parameters "$runParametersOutput"
  fi
}

# retry with a stable run version if restored version failed
fetch_run_parameters_safe() {
  fetch_run_parameters "$1"
  if [ "$runSucceed" -ne 0 ]; then
    fetch_run_parameters $minimumRunVersion
  fi
}

trace "Docker Image: $dockerImage"
trace "Version Request: $versionRequest"
trace "Cache TTL: $cacheTtl"

dockerArgs=""

if [ "$CHARTMAN_INTERACTIVE" = "1" ]; then dockerArgs="$dockerArgs -it"; fi

mkdir -p "/tmp/chartman"

if check_file_modified_within_seconds "$cacheFilePath" "$cacheTtl"; then
  trace "Cache parameters found $cacheFilePath"
  read_run_parameters "$(cat $cacheFilePath)"
else
  if [ -s "$latestFilePath" ]; then
    runVersion=$(<"$latestFilePath")
  else
    runVersion="$minimumRunVersion"
  fi

  fetch_run_parameters_safe $runVersion

  if [ "$latestVersion" != "$runVersion" ]; then
    fetch_run_parameters_safe $latestVersion
    echo "$latestVersion" > $latestFilePath
  fi

  echo "$runParametersOutput" > $cacheFilePath
fi

if [ "$latestVersion" != "$requestedVersion" ]; then
  >&2 echo "A newer version is available: $latestVersion"
fi
echo $requestedVersion
trace "Version: $requestedVersion"
trace "LatestVersion: $latestVersion"
trace "Docker Args: $runDockerArgs"

resolvedArgs=$(eval echo \"$runDockerArgs\")

trace "Resolved args: $resolvedArgs"
trace "docker run --rm $dockerArgs $resolvedArgs -w $PWD $dockerImage:$requestedVersion"

docker run --rm $dockerArgs $resolvedArgs -w $PWD $dockerImage:$requestedVersion "$@"
