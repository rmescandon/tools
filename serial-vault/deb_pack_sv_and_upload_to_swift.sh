#!/bin/bash

set -xe

. utilities.sh

DIR=$(pwd)
CI_DIR=$(mktemp -d)
PROJECT_NAME=serial-vault
PROJECT_REMOTE_URL=https://github.com/CanonicalLtd/serial-vault
SWIFT_REPO=$PROJECT_NAME

echo "Installing needed system dependencies"
sudo apt update
sudo apt install -y tar gzip swift git golang-go dpkg-dev

echo "Cloning and building project from sources"
cd $CI_DIR
git clone $PROJECT_REMOTE_URL $PROJECT_NAME
cd $PROJECT_NAME

echo "Build debian package"
dpkg-buildpackage -us -uc -rfakeroot
cd ..
DEB_NAME=$(ls $PROJECT_NAME*.deb)

echo "Creating tarball with deb"
TGZ_DIR=$(mktemp -d)
cd $TGZ_DIR
TGZ_BASE_NAME=$PROJECT_NAME.tgz
tar -cvzf $TGZ_BASE_NAME -C $CI_DIR $DEB_NAME

echo "Uploading to swift"
# calculate md5sum and rename sources with first 4 digits of md5sum
VERSION=`md5sum $TGZ_BASE_NAME | cut -c -4`
TGZ_NAME=$PROJECT_NAME-payload-$VERSION.tgz
mv $TGZ_BASE_NAME $TGZ_NAME

# upload to repo
swift_upload $SWIFT_REPO $TGZ_NAME

cd $DIR

echo "Done"







