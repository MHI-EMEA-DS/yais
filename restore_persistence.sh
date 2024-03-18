#!/bin/bash


ACCOUNT_NAME="mhiemeapublic"
CONTAINER_NAME="sxs-persistance-backups"
DESTINATION_FOLDER="/mhi/sxs/__data"
CHART_VERSION=""
FORCE="false"
CLEAN_UP_DESTINATION="false"
CHART_NAME="sxs"

showHelp() {
  echo "Usage: restore_persistence.sh -k <account-key> --chart-version <chart-version> [--destination /path/to/folder]  [-n <account-name>] [-c <container-name>] [--chart-version <version>] [--chart-name <chart-name>] [-f|--force]"
  echo "  -k, --account-key: Azure Storage account key"
  echo "  -n, --account-name: Azure Storage account name, Default: mhiemeapublic"
  echo "  -c, --container-name: Azure Storage container name, Default: sxs-persistance-backups"
  echo "  --destination: Destination folder, Default: /__data"
  echo "  --chart-name: Chart name (archive prefix), Default: sxs"
  echo "  --chart-version: Chart version, Default: trying to retrieve from chartman active version in /mhi/sxs"
  echo "  -f, --force: Force rewrite of the backup file"
  echo "  --clean-up-destination: Remove destination folder before restoring"
}

# Parse named parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--destination) DESTINATION_FOLDER="$2"; shift ;;
        -k|--key) ACCOUNT_KEY="$2"; shift ;;
        -f|--force) FORCE="true" ;;
        -n|--account-name) ACCOUNT_NAME="$2"; shift ;;
        -c|--container-name) CONTAINER_NAME="$2"; shift ;;
        --chart-name) CHART_NAME="$2"; shift ;;
        --chart-version) CHART_VERSION="$2"; shift ;;
        --clean-up-destination) CLEAN_UP_DESTINATION="true" ;;
        -h|--help) showHelp; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

ARCHIVE_NAME="${CHART_NAME}-${CHART_VERSION}.tar.gz"

if [ -z "$CHART_VERSION" ] || [ -z "$ACCOUNT_KEY" ]; then
  echo "Missing required parameters" >&2
  showHelp
  exit 1
fi

TEMP_DIR=$(mktemp -d)

docker run --rm -v ${TEMP_DIR}:/data mcr.microsoft.com/azure-cli az storage blob download \
    --account-name $ACCOUNT_NAME \
    --account-key $ACCOUNT_KEY \
    --container-name $CONTAINER_NAME \
    --name $ARCHIVE_NAME \
    --file /data/$ARCHIVE_NAME

if [ "$FORCE" == "true" ] && [ -d "$DESTINATION_FOLDER" ] && [ "$CLEAN_UP_DESTINATION" == "true" ]; then
  rm -rf $DESTINATION_FOLDER
fi

if [ -d "$DESTINATION_FOLDER" ] && [ "$FORCE" == "false" ]; then
  echo "Destination folder $DESTINATION_FOLDER already exists. Use -f to overwrite it" >&2
  exit 1
fi

mkdir -p $DESTINATION_FOLDER

tar -xzf $TEMP_DIR/$ARCHIVE_NAME -C $DESTINATION_FOLDER

rm -rf $TEMP_DIR

echo "Restored $ARCHIVE_NAME to $DESTINATION_FOLDER"
