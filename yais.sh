#!/usr/bin/bash

getHome() {
  USE_ORIGINAL=$1
  if [[ "$USE_ORIGINAL" == "1" && -n "$SUDO_USER" ]]; then
      IFS=: read -ra ADDR <<< "$(getent passwd "$SUDO_USER")"
      echo "${ADDR[5]}"
  else
      echo $HOME
  fi
}

ARG_DOCKER_REGISTRY_URL=''
ARG_DOCKER_REGISTRY_USER=''
ARG_DOCKER_REGISTRY_PASSWORD=''

ARG_MAIN_STACK_NAME='SXS_MAIN_STACK'
ARG_MAIN_STACK_NETWORK='gccp'
ARG_MAIN_STACK_DIR='/mhi'
ARG_MAIN_SERVICE_DIR='/mhi'
ARG_MAIN_SERVICE_CHART='@mhie-ds/charts-metals-iog'
ARG_CHARTMAN_HOME=""
ARG_CHARTMAN_UI_USER=''
ARG_CHARTMAN_UI_PASSWORD=''
ARG_CHARTMAN_UI_PORT=2314
ARG_CHARTMAN_UI_PORTS=''
ARG_CHARTMAN_UI_DATA='/chartman-ui'
ARG_CHARTMAN_UI_CONTAINER='chartman_docker_operator_ui'
ARG_CHARTMAN_UI_IMAGE=''
ARG_CHARTMAN_UI_IMAGE_TAG=''
ARG_NPMRC_FILE=""
ARG_USE_ORIGINAL_HOME_PATH='0'
ARG_MIGRATE_CHARTMAN_HOME_FROM_ROOT='0'

current_time=$(date +"%Y-%m-%dT%H:%M:%S")
stack_id=$(uuidgen)

## --------------------------------
## Provide help if --help requested
## --------------------------------

if [[ "${1,,}" == "--help" ]]; then
  echo "Usage:"
  echo "install-script.sh --param1 value1 --param2 value2 ..."
  echo "Parameters:"
  echo ""
  echo "  --StackName           | Name for the default deployment stack."
  echo "                        | Default: 'SXS-MAIN-STACK'"
  echo "  --StackDir            | Stack base directory"
  echo "                        | Default: '/mhi'"
  echo "  --ServiceDir          | Service base directory. Must be inside or the same as base stack directory."
  echo "                        | Default: '/mhi'"
  echo "  --StackNetwork        | Name of the network shared for all stack services."
  echo "                        | Default: 'gccp'"
  echo "  --ServiceChart        | Name of the main service chart."
  echo "                        | Default: '@mhie-ds/charts-metals-iog'"
  echo "  --ChartmanHome        | Path to custom Chartman home directory."
  echo "                        | Default: '\$HOME/.chartman', where \$HOME could be the original home path or the sudo user home path, depending on the --UseOriginalHomePath parameter"
  echo "  --ChartmanUiPort      | Port on which Chartman GUI will be served."
  echo "                        | It will be bound to 127.0.0.1 only"
  echo "                        | It is obsolete, Please use ChartmanUiPorts, as it gives more flexibility"
  echo "                        | Default: 2314"
  echo "  --ChartmanUiPorts     | Comma separated list of ips and ports on which Chartman GUI will be served."
  echo "                        | In case both --ChartmanUiPort and --ChartmanUiPorts are provided, --ChartmanUiPorts will be used."
  echo "                        | Example: --ChartmanUiPorts 127.0.0.1:2314,192.168.0.101:2377,127.0.0.1:2315"
  echo "                        | Default: '' (empty)"
  echo "  --ChartmanUiContainer | Name for the Chartman GUI container."
  echo "                        | Default: 'chartman_docker_operator_ui'"
  echo "  --DockerRegistry      | Url of the docker registry."
  echo "                        | [REQUIRED]"
  echo "  --User                | User for Chartman Docker Operator UI."
  echo "                        | [OPTIONAL]"
  echo "  --Password            | Password for Chartman Docker Operator UI"
  echo "                        | [OPTIONAL]"
  echo "  --RegistryUser        | User for docker registry."
  echo "                        | User for registry"
  echo "  --RegistryPassword    | Password/Token for docker registry."
  echo "                        | [REQUIRED]"
  echo "  --ChartmanUiImage     | Name of Chartman Docker Operator UI iamge."
  echo "                        | Default: 'chartman-operator-ui'"
  echo "  --ChartmanUiImageTag  | Version of Chartman Docker Operator UI image to be installed."
  echo "                        | [REQUIRED]"
  echo "  --ChartmanUiData      | Directory name to store all Chartman Docker Operator UI related data"
  echo "                        | Default: '/chartman-operator'"
  echo "  --NpmRcFile           | Path to .npmrc file"
  echo "                        | Default: '\$HOME/.npmrc', where \$HOME could be the original home path or the sudo user home path, depending on the --UseOriginalHomePath parameter"
  echo "  --UseOriginalHomePath | Use original home path for Chartman UI data directory, when script is used with sudo. Use 1 if you want to use original home path, any other value otherwise."
  echo "                        | Default: '0'"
  echo "  --MigrateChartmanHomeFromRoot | Migrate Chartman home directory from root to sudo user home directory. Use 1 if you want to migrate, any other value otherwise. "
  echo "                                | It will be ignored if --UseOriginalHomePath is 0 or --ChartmanHome is provided."
  echo "                                | Be careful, it can overwrite the existing Chartman home directory in sudo user home directory."
  echo "                                | Default: '0'"
  echo "  --help                | Display help"
  exit
fi

## ---------------------------
## Process all script arguments
## ---------------------------

echo "Validating arguments..."
sleep 1

isKey=1
keyName=''

for arg in "$@"
do
  if [[ $isKey == 1 ]]; then
    keyName=${arg,,}
    isKey=0
  else
    if [[ $keyName == '--stackname' ]]; then
      ARG_MAIN_STACK_NAME="${arg}"
    elif [[ $keyName == '--stackdir' ]]; then
      ARG_MAIN_STACK_DIR="${arg}"
    elif [[ $keyName == '--servicedir' ]]; then
      ARG_MAIN_SERVICE_DIR="${arg}"
    elif [[ $keyName == '--stacknetwork' ]]; then
      ARG_MAIN_STACK_NETWORK="${arg}"
    elif [[ $keyName == '--servicechart' ]]; then
      ARG_MAIN_SERVICE_CHART="${arg}"
    elif [[ $keyName == '--chartmanhome' ]]; then
      ARG_CHARTMAN_HOME="${arg}"
    elif [[ $keyName == '--chartmanuiport' ]]; then
      ARG_CHARTMAN_UI_PORT="${arg}"
    elif [[ $keyName == '--chartmanuicontainer' ]]; then
      ARG_CHARTMAN_UI_CONTAINER="${arg}"
    elif [[ $keyName == '--dockerregistry' ]]; then
      ARG_DOCKER_REGISTRY_URL="${arg}"
    elif [[ $keyName == '--user' ]]; then
      ARG_CHARTMAN_UI_USER="$arg"
    elif [[ $keyName == '--password' ]]; then
      ARG_CHARTMAN_UI_PASSWORD="$arg"
    elif [[ $keyName == '--registrypassword' ]]; then
      ARG_DOCKER_REGISTRY_PASSWORD="${arg}"
    elif [[ $keyName == '--registryuser' ]]; then
      ARG_DOCKER_REGISTRY_USER="${arg}"
    elif [[ $keyName == '--chartmanuidata' ]]; then
      ARG_CHARTMAN_UI_DATA="${arg}"
    elif [[ $keyName == '--chartmanuiimage' ]]; then
      ARG_CHARTMAN_UI_IMAGE="${arg}"
    elif [[ $keyName == '--chartmanuiimagetag' ]]; then
      ARG_CHARTMAN_UI_IMAGE_TAG="${arg}"
    elif [[ $keyName == '--chartmanuiports' ]]; then
      ARG_CHARTMAN_UI_PORTS="${arg}"
    elif [[ $keyName == '--useoriginalhomepath' ]]; then
      ARG_USE_ORIGINAL_HOME_PATH="${arg}"
    elif [[ $keyName == '--migratechartmanhomefromroot' ]]; then
      ARG_MIGRATE_CHARTMAN_HOME_FROM_ROOT="${arg}"
    elif [[ $keyName == '--npmrcfile' ]]; then
      ARG_NPMRC_FILE="${arg}"
      if [ ! -f "$file_path" ]; then
        echo "Provided npmrc file path is not valid. File not found".
        echo "Provide correct file path or skip the parameter"
        exit
      else
        echo "Using provided npmrc file: ${ARG_NPMRC_FILE}"
      fi
    else
      echo "Unknown parameter provided: ${keyName}"
      exit
    fi

    keyName=''
    isKey=1
  fi
done



if [[ "$ARG_NPMRC_FILE" == "" ]]; then
  ARG_NPMRC_FILE="$(getHome $ARG_USE_ORIGINAL_HOME_PATH)/.npmrc"
  echo "Using default npmrc file: ${ARG_NPMRC_FILE}"
fi

if [[ "$ARG_CHARTMAN_HOME" == "" ]]; then
  ARG_CHARTMAN_HOME="$(getHome $ARG_USE_ORIGINAL_HOME_PATH)/.chartman"
  echo "Using default Chartman home directory: ${ARG_CHARTMAN_HOME}"

  if [[ "$ARG_USE_ORIGINAL_HOME_PATH" == "1" ]]; then
    if [[ "$ARG_MIGRATE_CHARTMAN_HOME_FROM_ROOT" == "1" ]]; then
      if [[ -n "$SUDO_USER" ]]; then  # if script is run with sudo
        if [ -d "$(getHome 0)/.chartman" ]; then # if root home directory has .chartman directory
          if [[ "$(getHome 0)" != "$(getHome 1)" ]]; then # if root home directory is different from sudo user home directory
            echo "Migrating Chartman home directory from $(getHome 0)/.chartman to $ARG_CHARTMAN_HOME home directory"
            mkdir -p $ARG_CHARTMAN_HOME
            sudo cp -r "$(getHome 0)/.chartman/*" $ARG_CHARTMAN_HOME
            sudo chown -R $SUDO_USER:$SUDO_USER $ARG_CHARTMAN_HOME
          fi
        fi
      fi
    fi
  fi
fi

if [ ! -f "$ARG_NPMRC_FILE" ]; then
    echo "@mhie-ds:registry=https://pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/registry/
; begin auth token
//pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/registry/:username=NpmMhi
//pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/registry/:_password=<your_npm_pat>
//pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/registry/:email=CiUser01@ds.mhie.com
//pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/:username=NpmMhi
//pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/:_password=<your_npm_pat>
//pkgs.dev.azure.com/MHIE/_packaging/NpmMhi/npm/:email=CiUser01@ds.mhie.com
; end auth token" > "$ARG_NPMRC_FILE"
    echo ".npmrc file was not found in $ARG_NPMRC_FILE."
    echo "template .npmrc file was created in $ARG_NPMRC_FILE."
    echo "please update it with your credentials"
    exit
fi

# ----------------------------------------------------------
# Checking for the presence of a file with user and password
# ----------------------------------------------------------

USER_FILE_PATH=$ARG_CHARTMAN_UI_DATA/persistence/users.json

if test -f "$USER_FILE_PATH"; then
  echo "Users file exist"
fi

## ------------------
## Validate arguments
## ------------------

if [[ $ARG_CHARTMAN_UI_IMAGE_TAG == '' ]]; then
  read -p "Provide image tag: " ARG_CHARTMAN_UI_IMAGE_TAG
  if [[ $ARG_CHARTMAN_UI_IMAGE_TAG == '' ]]; then
    echo "Image tag cannot be empty"
    exit
  fi
fi
if [[ $ARG_DOCKER_REGISTRY_URL == '' ]]; then
  read -p "Docker registry url: " ARG_DOCKER_REGISTRY_URL
  if [[ $ARG_DOCKER_REGISTRY_URL == '' ]]; then
    echo "Docker registry cannot be empty"
    exit
  fi
fi
if [[ $ARG_DOCKER_REGISTRY_USER == '' ]]; then
  read -p "Docker registry user: " ARG_DOCKER_REGISTRY_USER
  if [[ $ARG_DOCKER_REGISTRY_USER == '' ]]; then
    echo "Docker registry username cannot be empty"
    exit
  fi
fi
if [[ $ARG_DOCKER_REGISTRY_PASSWORD == '' ]]; then
  read -p "Docker registry token: " ARG_DOCKER_REGISTRY_PASSWORD
  if [[ $ARG_DOCKER_REGISTRY_PASSWORD == '' ]]; then
    echo "Docker registry token cannot be empty"
    exit
  fi
fi
if [[ $ARG_CHARTMAN_UI_IMAGE == '' ]]; then
  ARG_CHARTMAN_UI_IMAGE="$ARG_DOCKER_REGISTRY_URL/chartman/docker-operator-ui"
fi

echo "Starting Chartman UI with parameters:"
echo ""
echo "Main Stack Name:         ${ARG_MAIN_STACK_NAME}"
echo "Main Stack Directory:    ${ARG_MAIN_STACK_DIR}"
echo "Main Stack Network:      ${ARG_MAIN_STACK_NETWORK}"
echo "Main Service Directory:  ${ARG_MAIN_SERVICE_DIR}"
echo "Main Service Chart:      ${ARG_MAIN_SERVICE_CHART}"
echo "Chartman home Directory: ${ARG_CHARTMAN_HOME}"
echo "GUI User:                ${ARG_CHARTMAN_UI_USER}"
if [[ $ARG_CHARTMAN_UI_PASSWORD == '' ]]; then
    echo "GUI Password:"
else
    echo "GUI Password:            ***********"
fi
if [[ -n $ARG_CHARTMAN_UI_PORTS ]]; then
  echo "GUI Ports:               ${ARG_CHARTMAN_UI_PORTS}"
else
  echo "GUI Port:                ${ARG_CHARTMAN_UI_PORT}"
fi
echo "GUI Container Name:      ${ARG_CHARTMAN_UI_CONTAINER}"
echo "GUI Image:               ${ARG_CHARTMAN_UI_IMAGE}"
echo "GUI Image Version/Tag:   ${ARG_CHARTMAN_UI_IMAGE_TAG}"
echo "GUI Data Directory:      ${ARG_CHARTMAN_UI_DATA}"
echo "Docker Registry:         ${ARG_DOCKER_REGISTRY_URL}"
echo "Docker registry user:    ${ARG_DOCKER_REGISTRY_USER}"
echo "Docker registry token:   ***********"
echo ""
sleep 1

# ----------------------------------------
# Create required directories if not exist
# ----------------------------------------

echo "Checking $ARG_CHARTMAN_UI_DATA directory"
sleep 1

if [ ! -d "${ARG_CHARTMAN_UI_DATA}" ]; then
  echo "${ARG_CHARTMAN_UI_DATA} directory is missing. Creating..."
  mkdir -p "${ARG_CHARTMAN_UI_DATA}"
  echo "Creating ${ARG_CHARTMAN_UI_DATA}/persistence directory"
  mkdir -p "${ARG_CHARTMAN_UI_DATA}/persistence"
  echo "Creating ${ARG_CHARTMAN_UI_DATA}/settings directory"
  mkdir -p "${ARG_CHARTMAN_UI_DATA}/settings"
else
  echo "${ARG_CHARTMAN_UI_DATA} directory already exists"
  if [ ! -d "${ARG_CHARTMAN_UI_DATA}/persistence" ]; then
    echo "Creating ${ARG_CHARTMAN_UI_DATA}/persistence directory"
    mkdir -p "${ARG_CHARTMAN_UI_DATA}/persistence"
  else
     echo "${ARG_CHARTMAN_UI_DATA}/persistence directory already exists"
  fi
  if [ ! -d "${ARG_CHARTMAN_UI_DATA}/settings" ]; then
    echo "Creating ${ARG_CHARTMAN_UI_DATA}/settings directory"
    mkdir -p "${ARG_CHARTMAN_UI_DATA}/settings"
  else
    echo "${ARG_CHARTMAN_UI_DATA}/settings directory already exists"
  fi
fi

echo "Checking ${ARG_MAIN_STACK_DIR} directory"
sleep 1

# ----------------------
# Init chartman function
# ----------------------

initializeChartman () {
  if [ ! -d "$1" ]; then
    echo "Creating $1 directory"
    mkdir -p $1
  fi
  if [ ! -d "${1}/.chartman" ]; then
    current_dir=$PWD
    cd $1

    echo "Chartman project is not yet initialized."
    echo "Performing 'chartman init ${ARG_MAIN_SERVICE_CHART}' in ${1} directory"
    mkdir .chartman
    echo '{ "chart": "'${ARG_MAIN_SERVICE_CHART}'", "deployments": []}' > ${1}/.chartman/state.json
    cd $current_dir
  fi
}

# ------------------------------------
# Create necessary service directories
# ------------------------------------

if [[ "${ARG_MAIN_SERVICE_DIR}" == "${ARG_MAIN_STACK_DIR}"* ]]; then
  echo "Stack directory and service directory are valid"
  # create directory if not exists and init chartman if not done yet
  if [ ! -d "${ARG_MAIN_SERVICE_DIR}" ]; then
    echo "Stack or service directory are missing. Creating..."
    mkdir -p "${ARG_MAIN_SERVICE_DIR}"
    initializeChartman "${ARG_MAIN_SERVICE_DIR}"
  else
    if [ ! -d "${ARG_MAIN_SERVICE_DIR}/.chartman" ]; then
      initializeChartman "${ARG_MAIN_SERVICE_DIR}"
    fi
  fi
else
  echo "Wrong service directory. Must start in the same directory as main stack: ${ARG_MAIN_STACK_DIR}"
  exit
fi

# ------------------------------------
# Prepare config and persistence files
# ------------------------------------

echo "Preparing config files..."
sleep 1

if [ -f "${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json" ]; then
  echo "Persistence file '${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json' already exists."
  echo "Checking values from current persistence file..."
  stacks_json=$(cat "${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json")
  stack_name=$(echo $(echo "$stacks_json" |grep -o '"Name": "[^"]*' | sed 's/"Name": "//') | cut -d ' ' -f 1)
  network=$(echo "$stacks_json" | grep -o '"Network": "[^"]*' | sed 's/"Network": "//')
  working_dir=$(echo $(echo "$stacks_json" | grep -o '"WorkingDir": "[^"]*' | sed 's/"WorkingDir": "//') | cut -d ' ' -f 1)
  if [[ ${ARG_MAIN_STACK_NAME} == "$stack_name" && ${ARG_MAIN_STACK_DIR} == "$working_dir" && ${ARG_MAIN_STACK_NETWORK} == "$network" ]]; then
     echo "using stacks.json from ${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json"
  else
     echo "${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json contains values different from args"
     echo "Error: provide the same stack name -- ${stack_name}, working dir -- ${working_dir}, network -- ${network} or remove ${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json"
     exit
  fi
else
  persistence_template="[
    {
      \"Id\": \"${stack_id}\",
      \"Name\": \"${ARG_MAIN_STACK_NAME}\",
      \"Network\": \"${ARG_MAIN_STACK_NETWORK}\",
      \"WorkingDir\": \"${ARG_MAIN_STACK_DIR}\",
      \"CreatedAt\": \"${current_time}\",
      \"UpdatedAt\": \"${current_time}\",
      \"Services\": []
    }
  ]"
  echo "${persistence_template}" > "${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json"
  echo "'${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json' file created"
fi
sleep 1

if [[ -f "${ARG_CHARTMAN_UI_DATA}/settings/config.json" ]]; then
  echo "Settings file already exists."
  backup_time=$(date +"%Y%m%d%H%M%S")
  backup_file="config_bcp_${backup_time}.json"
  echo "Creating backup file for existing configuration: ${backup_file}"
  sleep 1

  cp "${ARG_CHARTMAN_UI_DATA}/settings/config.json" "${ARG_CHARTMAN_UI_DATA}/settings/${backup_file}"
fi

config_hostname=""

config_template="{
  \"Hostname\": \"${config_hostname}\",
  \"Port\": ${ARG_CHARTMAN_UI_PORT},
  \"CrossNavigationUrl\": \"n/a\",
  \"Protocol\": \"http\",
  \"Prefix\": \"\",
  \"LogLevel\": \"warning\"
}"

echo "${config_template}" > "${ARG_CHARTMAN_UI_DATA}/settings/config.json"
echo "'${ARG_CHARTMAN_UI_DATA}/settings/config.json' file created"
sleep 1

# --------------------------
# Function for checking user
# --------------------------

runChartmanOperatorCommand () {
  COMMON_ARGS="-e DOCKER_REGISTRY=$ARG_DOCKER_REGISTRY_URL \
    -e DOCKER_USER=$ARG_DOCKER_REGISTRY_USER \
    -e DOCKER_PW=$ARG_DOCKER_REGISTRY_PASSWORD \
    -v "${ARG_MAIN_STACK_DIR}":"${ARG_MAIN_STACK_DIR}" \
    -v "${ARG_CHARTMAN_HOME}":" " \
    -v "/var/run/docker.sock":"/var/run/docker.sock" \
    -v "${ARG_CHARTMAN_UI_DATA}/persistence":"/chartman-operator/data" \
    -v "${ARG_CHARTMAN_UI_DATA}/settings/config.json":"/wwwroot/config.json" \
    $ARG_CHARTMAN_UI_IMAGE:$ARG_CHARTMAN_UI_IMAGE_TAG"

  if [ $1  == "set-user" ]; then
    ARGS="--rm $COMMON_ARGS set-user -u $ARG_CHARTMAN_UI_USER -p $ARG_CHARTMAN_UI_PASSWORD"
  elif [ $1 == "server" ]; then
    if [ -n "$ARG_CHARTMAN_UI_PORTS" ]; then
      PORT_MAPPING=""
      PUBLIC_PORTS_ASSIGNMENT="$ARG_CHARTMAN_UI_PORTS"
      IFS=',' read -ra parts <<< "$ARG_CHARTMAN_UI_PORTS"
          for part in "${parts[@]}"; do
            PORT_MAPPING="$PORT_MAPPING -p $part:80"
          done
    else
      PORT_MAPPING="-p 127.0.0.1:$ARG_CHARTMAN_UI_PORT:80"
      PUBLIC_PORTS_ASSIGNMENT="127.0.0.1:$ARG_CHARTMAN_UI_PORT"
    fi

    ARGS="-d --restart unless-stopped --name $ARG_CHARTMAN_UI_CONTAINER $PORT_MAPPING -e PUBLIC_PORTS_ASSIGNMENT=$PUBLIC_PORTS_ASSIGNMENT -v $ARG_NPMRC_FILE:/root/.npmrc $COMMON_ARGS server"
  fi

  docker run $ARGS
}

# -------------------
# Run docker commands
# -------------------

echo "Login to docker registry"
sleep 1
docker login $ARG_DOCKER_REGISTRY_URL -u $ARG_DOCKER_REGISTRY_USER -p $ARG_DOCKER_REGISTRY_PASSWORD

echo "Pulling docker images"
sleep 1
docker pull $ARG_CHARTMAN_UI_IMAGE:$ARG_CHARTMAN_UI_IMAGE_TAG

echo "Starting docker container for Chartman UI"
sleep 1

docker stop $ARG_CHARTMAN_UI_CONTAINER > /dev/null 2>&1
docker rm -f $ARG_CHARTMAN_UI_CONTAINER > /dev/null 2>&1

if [[ "$ARG_CHARTMAN_UI_USER" != "" ]]; then
  runChartmanOperatorCommand "set-user"
fi

runChartmanOperatorCommand "server"
