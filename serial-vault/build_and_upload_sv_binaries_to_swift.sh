#!/bin/bash

set -e

. utilities

clean_on_exit() {
  rm -rf $1
  rm -rf $2
  export GOPATH=
  export GOROOT=
  export GOBIN=
#  export https_proxy=
#  export http_proxy=
}

DIR=$(pwd)
GOPATH_TMPDIR=$(mktemp -d)
GOROOT_TMPDIR=$(mktemp -d)
export GOPATH=${GOPATH_TMPDIR}
export GOROOT=${GOROOT_TMPDIR}/go
export GOBIN=${GOPATH}/bin
PATH=${GOROOT}/bin:${GOBIN}:${PATH}

trap "clean_on_exit ${GOPATH_TMPDIR} ${GOROOT_TMPDIR}" EXIT
trap "clean_on_exit ${GOPATH_TMPDIR} ${GOROOT_TMPDIR}" ERR

PROXY=http://squid.internal:3128/
WORKSPACE=${GOPATH}/src/github.com/CanonicalLtd
PROJECT_NAME=serial-vault.canonical.com
PROJECT_REMOTE_URL=https://github.com/CanonicalLtd/serial-vault
RELEASE_TAG=2.0-1
SWIFT_REPO=${PROJECT_NAME}
export http_proxy=${PROXY}
export https_proxy=${PROXY}

# list vars in use and their values
echo "GOPATH=${GOPATH}"
echo "PATH=${PATH}"
echo "PROXY=${PROXY}"
echo "WORKSPACE=${WORKSPACE}"
echo "PROJECT_NAME=${PROJECT_NAME}"
echo "PROJECT_REMOTE_URL=${PROJECT_REMOTE_URL}"
echo "RELEASE_TAG=${RELEASE_TAG}"
echo "SWIFT_REPO=${SWIFT_REPO}"

echo "Installing go 1.6"
cd ${GOROOT_TMPDIR}
curl -O https://storage.googleapis.com/golang/go1.6.linux-amd64.tar.gz
tar -zxvf go1.6.linux-amd64.tar.gz

echo "Creating environment..."
[ -d ${GOPATH}/bin ]  || mkdir ${GOPATH}/bin
[ -d ${WORKSPACE} ] || mkdir -p ${WORKSPACE}
cd ${WORKSPACE}

echo "Cloning and building project from sources..."
git clone -b ${RELEASE_TAG} --single-branch ${PROJECT_REMOTE_URL} ${PROJECT_NAME}
cd ${PROJECT_NAME}

#alias go="https_proxy=${PROXY} http_proxy=${PROXY} go"
#alias git="https_proxy=${PROXY} http_proxy=${PROXY} git"
go get -v launchpad.net/godeps
godeps -u dependencies.tsv
#go get -v -d ./...
go install -v ./...

echo "Creating tarball with binaries and assets..."
TGZ_DIR=$(mktemp -d)
cd ${TGZ_DIR}
TAR_BASE_NAME=${PROJECT_NAME}-v${RELEASE_TAG}.tar
# create tar file with  assets in 'static' folder
tar -cvf ${TAR_BASE_NAME} -C ${WORKSPACE}/${PROJECT_NAME} static
# update tar file with serial-vault and serial-vault-admin built binaries
tar -uvf ${TAR_BASE_NAME} -C ${GOPATH}/bin serial-vault serial-vault-admin
# compress with gzip
gzip -9 ${TAR_BASE_NAME}

echo "Uploading to swift..."
# calculate md5sum and rename sources with first 4 digits of md5sum
VERSION=`md5sum ${TAR_BASE_NAME}.gz | cut -c -4`
TGZ_NAME=${PROJECT_NAME}-payload-${VERSION}.tgz
mv ${TAR_BASE_NAME}.gz ${TGZ_NAME}

# upload to repo
swift_upload ${SWIFT_REPO} ${TGZ_NAME}

# update build_label with calculated version for the payload
export BUILD_LABEL=${VERSION}

cd ${DIR}

echo "Done."
