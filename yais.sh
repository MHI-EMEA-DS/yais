#!/usr/bin/bash

ARG_DOCKER_REGISTRY_URL=''
ARG_DOCKER_REGISTRY_USER=''
ARG_DOCKER_REGISTRY_PASSWORD=''

ARG_DOMAIN=''
ARG_MAIN_STACK_NAME='SXS_MAIN_SERVICE'
ARG_MAIN_STACK_NETWORK='gccp'
ARG_MAIN_STACK_DIR='/mhi'
ARG_MAIN_SERVICE_NAME='SXS_SERVICE'
ARG_MAIN_SERVICE_DIR='/mhi'
ARG_MAIN_SERVICE_CHART='@mhie-ds/iog-metals'
ARG_CHARTMAN_UI_USER=''
ARG_CHARTMAN_UI_PASSWORD=''
ARG_CHARTMAN_UI_PORT=2314
ARG_CHARTMAN_UI_DATA='/chartman-ui'
ARG_CHARTMAN_UI_CONTAINER='chartman_docker_operator_ui'
ARG_CHARTMAN_UI_IMAGE='chartman/docker-operator-ui'
ARG_CHARTMAN_UI_IMAGE_TAG=''

current_time=$(date +"%Y-%m-%dT%H:%M:%S")
stack_id=$(uuidgen)
service_id=$(uuidgen)

## --------------------------------
## Provide help if --help requested
## --------------------------------

if [[ "${1,,}" == "--help" ]]; then
  echo "Usage:"
  echo "install-script.sh --param1 value1 --param2 value2 ..."
  echo "Parameters:"
  echo ""
  echo "  --Domain              | Name for current network domain for deployment"
  echo "                        | [REQUIRED]. Example 'domain.com'"
  echo "  --StackName           | Name for the default deployment stack."
  echo "                        | Default: 'SXS-MAIN-STACK'"
  echo "  --ServiceName         | Name for the default deployment service."
  echo "                        | Default: 'SXS-MAIN-SERVICE'"
  echo "  --StackDir            | Stack base directory"
  echo "                        | Default: '/mhi'"
  echo "  --ServiceDir          | Service base directory. Must be inside or the same as base stack directory."
  echo "                        | Default: '/mhi'"
  echo "  --StackNetwork        | Name of the network shared for all stack services."
  echo "                        | Default: 'gccp'"
  echo "  --ServiceChart        | Name of the main service chart."
  echo "                        | Default: '@mhie-ds/iog-metals'"
  echo "  --ChartmanUiPort      | Port on which Chartman GUI will be served."
  echo "                        | Default: 2314"
  echo "  --ChartmanUiContainer | Name for the Chartman GUI container."
  echo "                        | Default: 'chartman_docker_operator_ui'"
  echo "  --DockerRegistry      | Url of the docker registry."
  echo "                        | [REQUIRED]"
  echo "  --User                | User for Chartman Docker Operator UI."
  echo "                        | "
  echo "  --Password            | Password for Chartman Docker Operator UI"
  echo "                        | "
  echo "  --RegistryUser        | User for docker registry."
  echo "                        | User for registry"
  echo "  --RegistryPassword    | Password/Token for docker registry."
  echo "                        | [REQUIRED]"
  echo "  --ChartmanUiImage     | Name of Chartman Docker Operator UI iamge."
  echo "                        | Default: 'chartman-operator-ui'"
  echo "  --ChartmanUiImageTag  | Version of Chartman Docker Operator UI image to be installed."
  echo "                        | [Required]"
  echo "  --ChartmanUiData      | Directory name to store all Chartman Docker Operator UI related data"
  echo "                        | Default: '/chartman-operator'"
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
    if [[ $keyName == '--domain' ]]; then
      ARG_DOMAIN="${arg}"
    elif [[ $keyName == '--stackname' ]]; then
      ARG_MAIN_STACK_NAME="${arg}"
    elif [[ $keyName == '--servicename' ]]; then
      ARG_MAIN_SERVICE_NAME="${arg}"
    elif [[ $keyName == '--stackdir' ]]; then
      ARG_MAIN_STACK_DIR="${arg}"
    elif [[ $keyName == '--servicedir' ]]; then
      ARG_MAIN_SERVICE_DIR="${arg}"
    elif [[ $keyName == '--stacknetwork' ]]; then
      ARG_MAIN_STACK_NETWORK="${arg}"
    elif [[ $keyName == '--servicechart' ]]; then
      ARG_MAIN_SERVICE_CHART="${arg}"
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
    else
      echo "Unknown parameter provided: ${keyName}"
      exit
    fi

    keyName=''
    isKey=1
  fi
done

# ----------------------------------------------------------
# Checking for the presence of a file with user and password
# ----------------------------------------------------------

USER_FILE_PATH=$ARG_CHARTMAN_UI_DATA/persistence/users.json
if test -f "$USER_FILE_PATH"; then
  echo "Users file exist"
else
  echo "File with users doesn't exist $USER_FILE_PATH"
  if [[ "$ARG_CHARTMAN_UI_USER" == '' ]]; then
    read -p "Provide user name: " ARG_CHARTMAN_UI_USER
    if [[ "$ARG_CHARTMAN_UI_USER" == '' ]]; then
      echo "User name cannot be empty"
      exit
    fi
  fi

  if [[ "$ARG_CHARTMAN_UI_PASSWORD" == '' ]]; then
    read -p "Provide user password: " ARG_CHARTMAN_UI_PASSWORD
    if [[ "$ARG_CHARTMAN_UI_PASSWORD" == '' ]]; then
       echo "User password cannot be empty"
       exit
    fi
  fi
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

if [[ $ARG_DOMAIN == '' ]]; then
  read -p "Provide current network domain: " ARG_DOMAIN
  if [[ $ARG_DOMAIN == '' ]]; then
    echo "Domain cannot be empty"
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

ARG_CHARTMAN_UI_IMAGE="${ARG_DOCKER_REGISTRY_URL}/${ARG_CHARTMAN_UI_IMAGE}"

echo "Starting Chartman UI with parameters:"
echo ""
echo "Domain:                 ${ARG_DOMAIN}"
echo "Main Stack Name:        ${ARG_MAIN_STACK_NAME}"
echo "Main Stack Directory:   ${ARG_MAIN_STACK_DIR}"
echo "Main Stack Network:     ${ARG_MAIN_STACK_NETWORK}"
echo "Main Service Name:      ${ARG_MAIN_SERVICE_NAME}"
echo "Main Service Directory: ${ARG_MAIN_SERVICE_DIR}"
echo "Main Service Chart:     ${ARG_MAIN_SERVICE_CHART}"
echo "GUI User:               ${ARG_CHARTMAN_UI_USER}"
echo "GUI Password:           ***********"
echo "GUI Port:               ${ARG_CHARTMAN_UI_PORT}"
echo "GUI Container Name:     ${ARG_CHARTMAN_UI_CONTAINER}"
echo "GUI Image:              ${ARG_CHARTMAN_UI_IMAGE}"
echo "GUI Image Version/Tag:  ${ARG_CHARTMAN_UI_IMAGE_TAG}"
echo "GUI Data Directory:     ${ARG_CHARTMAN_UI_DATA}"
echo "Docker Registry:        ${ARG_DOCKER_REGISTRY_URL}"
echo "Docker registry user:   ${ARG_DOCKER_REGISTRY_USER}"
echo "Docker registry token:  ***********"
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

if [[ "${ARG_MAIN_SERVICE_DIR}" == "${ARG_MAIN_STACK_DIR}"* ]]; then
  echo "Stack directory and service directory are valid"
  if [ ! -d "${ARG_MAIN_SERVICE_NAME}" ]; then
    echo "Stack or service directory are missing. Creating..."
    mkdir -p "${ARG_MAIN_SERVICE_NAME}"
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

if [ ! -f "${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json" ]; then
  persistence_template="[
    {
      \"Id\": \"${stack_id}\",
      \"Name\": \"${ARG_MAIN_STACK_NAME}\",
      \"Network\": \"${ARG_MAIN_STACK_NETWORK}\",
      \"WorkingDir\": \"${ARG_MAIN_STACK_DIR}\",
      \"CreatedAt\": \"${current_time}\",
      \"UpdatedAt\": \"${current_time}\",
      \"Services\": [
        {
          \"Id\": \"${service_id}\",
          \"Name\": \"${ARG_MAIN_SERVICE_NAME}\",
          \"WorkingDir\": \"${ARG_MAIN_SERVICE_DIR}\",
          \"Chart\": \"${ARG_MAIN_SERVICE_CHART}\",
          \"CreatedAt\": \"${current_time}\",
          \"UpdatedAt\": \"${current_time}\"
        }
      ]
    }
  ]"

  echo "${persistence_template}" > "${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json"
  echo "'${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json' file created"
  sleep 1
else
  echo "Persistence file '${ARG_CHARTMAN_UI_DATA}/persistence/stacks.json' already exists."
  echo "Existing file will be used as a persistence for Chartman UI"
  echo "For clean installation remove 'stack.json' file from '${ARG_CHARTMAN_UI_DATA}/persistence'"
  sleep 3
fi

if [[ -f "${ARG_CHARTMAN_UI_DATA}/settings/config.json" ]]; then
  echo "Settings file already exists."
  backup_time=$(date +"%Y%m%d%H%M%S")
  backup_file="config_bcp_${backup_time}.json"
  echo "Creating backup file for existing configuration: ${backup_file}"
  sleep 1

  cp "${ARG_CHARTMAN_UI_DATA}/settings/config.json" "${ARG_CHARTMAN_UI_DATA}/settings/${backup_file}"
fi

config_hostname="${HOSTNAME%%.*}.${ARG_DOMAIN}"
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
             -v "${HOME}/.chartman":"/app/data/.chartman" \
             -v "/var/run/docker.sock":"/var/run/docker.sock" \
             -v "${ARG_CHARTMAN_UI_DATA}/persistence":"/chartman-operator/data" \
             -v "${ARG_CHARTMAN_UI_DATA}/settings/config.json":"/wwwroot/config.json" \
             $ARG_CHARTMAN_UI_IMAGE:$ARG_CHARTMAN_UI_IMAGE_TAG"
  if [ $1  == "set-user" ]; then
    ARGS="--rm $COMMON_ARGS set-user -u $ARG_CHARTMAN_UI_USER -p $ARG_CHARTMAN_UI_PASSWORD"
  elif [ $1 == "server" ]; then
    ARGS="-d --name $ARG_CHARTMAN_UI_CONTAINER -p $ARG_CHARTMAN_UI_PORT:80 $COMMON_ARGS server"
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
