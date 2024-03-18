#!/bin/bash

ACCOUNT_NAME="mhiemeapublic"
CONTAINER_NAME="sxs-persistance-backups"
FOLDER_NAME="/mhi/sxs/__data"
FORCE="false"
CHART_NAME="sxs"
SXS_DIR="/mhi/sxs"


showHelp() {
  echo "Usage: backup_persistence.sh -k <account-key> [--folder /path/to/folder]  [-n <account-name>] [-c <container-name>] [--chart-version <version>] [-f|--force] [--chart-name <chart-name>]"
  echo "  -k, --account-key: Azure Storage account key"
  echo "  -n, --account-name: Azure Storage account name, Default: mhiemeapublic"
  echo "  -c, --container-name: Azure Storage container name, Default: sxs-persistance-backups"
  echo "  --folder: Folder to backup, Default: /mhi/sxs/__data"
  echo "  --chart-name: Chart name (archive prefix), Default: sxs"
  echo "  --chart-version: Chart version, Default: trying to retrieve from chartman active version in /mhi/sxs"
  echo "  --sxs-dir: SXS directory, Default: /mhi/sxs"
  echo "  -f, --force: Force rewrite of the backup file"
}

getActiveDeploymentVersion() {
  if [ ! -d "$SXS_DIR" ]; then
      echo "Folder $SXS_DIR does not exist. cannot determine active deployment version." >&2
      return 1
  fi
  pushd $SXS_DIR > /dev/null

  local chartmanState=$(chartman state 2>&1)
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
      echo "Failed to get chartman state" >&2
      echo "$chartmanState" >&2
      return 1
  fi
  local chartmanState=$(chartman state)

  local activeDeployment=$(echo "$chartmanState" | jq -r '.activeDeployment')

  if [ "$activeDeployment" == "null" ] || [ -z "$activeDeployment" ]; then
      echo "No active deployment found." >&2
      echo "$chartmanState" >&2
      return 1
  fi

  local version=$(echo "$chartmanState" | jq -r --arg activeDeployment "$activeDeployment" '.deployments[] | select(.id==$activeDeployment) | .version')

  if [ "$version" == "null" ] || [ -z "$version" ]; then
      echo "Version for the active deployment '$activeDeployment' not found." >&2
      return 1
  fi

  echo "$version"

  popd > /dev/null
}

# Define cleanup function
cleanup() {
  if [ "$TEMP_FOLDER" != "" ] && [ -d "$TEMP_FOLDER" ]; then
    echo "Removing temp dir $TEMP_FOLDER"
    rm -rf $TEMP_FOLDER
  fi
}

trap cleanup EXIT

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --folder) FOLDER_NAME="$2"; shift ;;
        -k|--account-key) ACCOUNT_KEY="$2"; shift ;;
        -n|--account-name) ACCOUNT_NAME="$2"; shift ;;
        -c|--container-name) CONTAINER_NAME="$2"; shift ;;
        --chart-name) CHART_NAME="$2"; shift ;;
        --chart-version) CHART_VERSION="$2"; shift ;;
        --sxs-dir) SXS_DIR="$2"; shift ;;
        -f|--force) FORCE="true" ;;
        -h|--help) showHelp; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$FOLDER_NAME" ] || [ -z "$ACCOUNT_KEY" ]; then
    echo "Account key is required"
    showHelp
    exit 1
fi

if [ -z "$CHART_VERSION" ]; then
    echo "No chart version provided, trying to get it from chartman"
    CHART_VERSION=$(getActiveDeploymentVersion)
    if [ $CHART_VERSION == "" ]; then
        echo "Failed to get chart version from chartman"
        exit 1
    fi
    echo "Chart version: $CHART_VERSION"
fi

ARCHIVE_NAME="${CHART_NAME}-${CHART_VERSION}.tar.gz"
OVERWRITE_OPTION=""
# check if the file is already in the container
if [ "$FORCE" == "false" ]; then
    existsRaw=$(docker run --rm mcr.microsoft.com/azure-cli az storage blob exists \
        --account-name $ACCOUNT_NAME \
        --account-key $ACCOUNT_KEY \
        --container-name $CONTAINER_NAME \
        --name $ARCHIVE_NAME)
    exists=$(echo "$existsRaw" | jq '.exists')
    if [ "$exists" = "true" ]; then
        echo "Backup already exists in the container. Use -f to force rewrite. Or specify a different chart name or version."
        exit 1
    fi
  else
      OVERWRITE_OPTION="--overwrite"
fi

TEMP_FOLDER=$(mktemp -d)

tar -czf $TEMP_FOLDER/$ARCHIVE_NAME -C $FOLDER_NAME .

docker run --rm -v ${TEMP_FOLDER}:/data mcr.microsoft.com/azure-cli az storage blob upload \
    --account-name $ACCOUNT_NAME \
    --account-key $ACCOUNT_KEY \
    --container-name $CONTAINER_NAME \
    --file /data/$ARCHIVE_NAME \
    --name $ARCHIVE_NAME \
    $OVERWRITE_OPTION

rm -rf $TEMP_FOLDER
echo "Finished"
