#!/bin/sh

set -e

NAME=serial-vault-charm
URL=git@github.com:CanonicalLtd/serial-vault-charm.git
OWNER=canonical-solutions
HOMEPAGE=https://github.com/CanonicalLtd/serial-vault-charm
ISSUES=https://github.com/CanonicalLtd/serial-vault-charm/issues
SERIES=xenial

check_valid_series() {
	if [ "$(lsb_release -cs)" != "$SERIES" ]; then
		echo "Sorry, this releasing script can only be executed on $SERIES"
		exit 1
	fi
}

add_juju_repo_if_needed() {
	if [ $(grep ^ /etc/apt/sources.list /etc/apt/sources.list.d/* | grep -v list.save | grep -v deb-src | grep deb | grep juju-ubuntu-stable | wc -l) -eq 0 ]; then
		echo "adding juju stable repository..."
		sudo add-apt-repository ppa:juju/stable
		sudo apt update
	fi
}

install_pkg_if_needed() {
	if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
		sudo apt install $1
	fi
}

show_help() {
    exec cat <<EOF
Usage: build_and_release_charm.sh [OPTIONS]

optional arguments:
  --help                           Show this help message and exit
  --name=<name>                    Name of the charm in the store (default: $NAME)
  --url=<url>                      Repository url from where to get the charm sources (default: $URL)
  --owner=<owner>                  Owner of the charm in the store (default: $OWNER)
  --homepage=<homepage>            Url of the project homepage (default: $HOMEPAGE)
  --issues=<issues>                Url where filing issues for the project (default: $ISSUES)
EOF
}

while [ -n "$1" ]; do
	case "$1" in
		--help)
			show_help
			exit
			;;
		--name=*)
			NAME=${1#*=}
			shift
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
[ -n $JUJU_REPOSITORY ] 				|| JUJU_REPOSITORY=./charms
[ -e $JUJU_REPOSITORY/layers/$NAME ] 	|| git clone $URL $JUJU_REPOSITORY/layers/$NAME
charm build $JUJU_REPOSITORY/layers/$NAME

# publish in store
charm login
VERSION=`charm push $JUJU_REPOSITORY/builds/$NAME | grep -Po "(?<=$NAME-)\d+")`

# promote charm to all channels, grant permissions and set homepage and issues urls
charm release cs:~$OWNER/$NAME-$VERSION --channel edge
charm release cs:~$OWNER/$NAME-$VERSION --channel beta
charm release cs:~$OWNER/$NAME-$VERSION --channel candidate
charm release cs:~$OWNER/$NAME-$VERSION --channel stable

charm grant cs:~$OWNER/$NAME-$VERSION --acl read everyone

charm set cs:~$OWNER/$NAME --channel stable homepage=$HOMEPAGE
charm set cs:~$OWNER/$NAME --channel stable bugs-url=$ISSUES

echo "cs:~$OWNER/$NAME build and release finished Ok."
