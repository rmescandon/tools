#!/bin/sh
swift_upload() {
    do_swift upload $1 $2
}

swift_download() {
    do_swift download $1 $2
}

# $1 command
# $2 container
# $3 file
do_swift() {
    swift \
    --os-auth-url $OS_AUTH_URL \
    --os-tenant-name $OS_TENANT_NAME \
    --os-username $OS_USERNAME \
    --os-password $OS_PASSWORD \
    --os-region-name $OS_REGION_NAME \
    $1 $2 $3
}