#!/bin/bash

set -e

. utilities.sh

DIR=$(pwd)
GOPATH=$(mktemp -d)
PATH=$PATH:$GOPATH/bin

WORKSPACE=$GOPATH/src/github.com/CanonicalLtd
PROJECT_NAME=serial-vault
PROJECT_REMOTE_URL=https://github.com/CanonicalLtd/serial-vault
RELEASE_TAG=2.0-1
SWIFT_REPO=$PROJECT_NAME

echo "Creating environment..."
[ -d $GOPATH/bin ]  || mkdir $GOPATH/bin
[ -d $WORKSPACE ] || mkdir -p $WORKSPACE
cd $WORKSPACE

echo "Installing needed system dependencies..."
sudo apt update
sudo apt install -y tar gzip swift git golang-go

echo "Cloning and building project from sources..."
git clone -b $RELEASE_TAG --single-branch $PROJECT_REMOTE_URL $PROJECT_NAME
cd $PROJECT_NAME

go get launchpad.net/godeps
godeps -u dependencies.tsv
go install -v ./...

echo "Creating tarball with binaries and assets..."
TGZ_DIR=$(mktemp -d)
cd $TGZ_DIR
TAR_BASE_NAME=$PROJECT_NAME-v$RELEASE_TAG.tar
# create tar file with  assets in 'static' folder
tar -cvf $TAR_BASE_NAME -C $WORKSPACE/$PROJECT_NAME static
# update tar file with serial-vault and serial-vault-admin built binaries
tar -uvf $TAR_BASE_NAME -C $GOPATH/bin serial-vault serial-vault-admin
# compress with gzip
gzip -9 $TAR_BASE_NAME

echo "Uploading to swift..."
# calculate md5sum and rename sources with first 4 digits of md5sum
VERSION=`md5sum $TAR_BASE_NAME.gz | cut -c -4`
TGZ_NAME=$PROJECT_NAME-payload-$VERSION.tgz
mv $TAR_BASE_NAME.gz $TGZ_NAME

# upload to repo
swift_upload $SWIFT_REPO $TGZ_NAME

cd $DIR

echo "Done."





