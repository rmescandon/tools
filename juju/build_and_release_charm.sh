#!/bin/bash

set -e

URL=https://github.com/CanonicalLtd/serial-vault-charm.git
OWNER=canonical-solutions
HOMEPAGE=https://github.com/CanonicalLtd/serial-vault-charm
ISSUES=https://github.com/CanonicalLtd/serial-vault-charm/issues
SERIES=xenial
CHANNEL=stable

check_valid_series() {
	if [ "$(lsb_release -cs)" != "${SERIES}" ]; then
		echo "Sorry, this releasing script can only be executed on ${SERIES}"
		exit 1
	fi
}

add_juju_repo_if_needed() {
	if [ "$(grep ^ /etc/apt/sources.list /etc/apt/sources.list.d/* | grep -v list.save | grep -v deb-src | grep deb | grep juju-ubuntu-stable | wc -l)" -eq "0" ]; then
		echo "adding juju stable repository..."
		sudo add-apt-repository ppa:juju/stable
		sudo apt update
	fi
}

install_pkg_if_needed() {
	if [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c 'ok installed')" -eq "0" ]; then
		sudo apt install "$1"
	fi
}

# $1 name of the charm to release
release_to_channels() {
# promote charm to requested channel and the ones less critical than that.
case "$CHANNEL" in
	stable)
		charm release cs:~"${OWNER}"/"$1"-"${VERSION}" --channel stable
		;&
	candidate)
		charm release cs:~"${OWNER}"/"$1"-"${VERSION}" --channel candidate
		;&
	beta)
		charm release cs:~"${OWNER}"/"$1"-"${VERSION}" --channel beta
		;&
	edge)
		charm release cs:~"${OWNER}"/"$1"-"${VERSION}" --channel edge
		exit
		;;
esac
}

# got from https://gist.github.com/pkuczynski/8665367
parse_yaml() {
	local prefix="$2"
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
	sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
    	-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   	awk -F$fs '{
    	indent = length($1)/2;
      	vname[indent] = $2;
      	for (i in vname) {if (i > indent) {delete vname[i]}}
      	if (length($3) > 0) {
        	vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        	printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      	}
   	}'
}

show_help() {
    exec cat <<EOF
Usage: build_and_release_charm.sh [OPTIONS]

optional arguments:
  --help                           Show this help message and exit
  --url=<url>                      Repository url from where to get the charm sources (default: $URL)
  --owner=<owner>                  Owner of the charm in the store (default: $OWNER)
  --homepage=<homepage>            Url of the project homepage (default: $HOMEPAGE)
  --issues=<issues>                Url where filing issues for the project (default: $ISSUES)
  --channel=<channel>              Most critical channel to publish the charm. It'll be publish in that one and any less critical (defautl: $CHANNEL)
EOF
}

while [ -n "$1" ]; do
	case "$1" in
		--help)
			show_help
			exit
			;;
		--url=*)
			URL=${1#*=}
			shift
			;;
		--owner=*)
			OWNER=${1#*=}
			shift
			;;
		--version=*)
			VERSION=${1#*=}
			shift
			;;
		--homepage=*)
			HOMEPAGE=${1#*=}
			shift
			;;
		--issues=*)
			ISSUES=${1#*=}
			shift
			;;
		--channel=*)
			CHANNEL=${1#*=}
			shift
			;;
		*)
			echo "Unknown command: $1"
			exit 1
			;;
	esac
done

check_valid_series

add_juju_repo_if_needed
install_pkg_if_needed charm
install_pkg_if_needed charm-tools

# clone and build charm from sources
project_name=$(basename "${URL}" | cut -d'.' -f1)
[ -n "${JUJU_REPOSITORY}" ] 						|| JUJU_REPOSITORY=$(mktemp -d)/charms
[ -e "${JUJU_REPOSITORY}"/layers/"${project_name}" ] 	|| git clone "${URL}" "${JUJU_REPOSITORY}"/layers/"${project_name}"
charm build -o "${JUJU_REPOSITORY}" "${JUJU_REPOSITORY}"/layers/"${project_name}"

# get charm properties by parsing metadata.yaml file and assign their created vars 'charm_' prefix
eval "$(parse_yaml "${JUJU_REPOSITORY}"/layers/"${project_name}"/metadata.yaml 'charm_')"

# publish in store
charm login
VERSION=$(charm push "${JUJU_REPOSITORY}"/builds/"${charm_name}" | grep -Po "(?<=${charm_name}-)\d+")

release_to_channels "${charm_name}"

charm grant cs:~"${OWNER}"/"${charm_name}"-"${VERSION}" --acl read everyone

charm set cs:~"${OWNER}"/"${charm_name}" --channel stable homepage="${HOMEPAGE}"
charm set cs:~"${OWNER}"/"${charm_name}" --channel stable bugs-url="${ISSUES}"

echo "cs:~${OWNER}/${charm_name} build and release finished Ok."
