#!/bin/sh

set -e

NAME=serial-vault-charm
URL=git@github.com:CanonicalLtd/serial-vault-charm.git
OWNER=canonical-solutions
HOMEPAGE=https://github.com/CanonicalLtd/serial-vault-charm
ISSUES=https://github.com/CanonicalLtd/serial-vault-charm/issues

add_juju_repo_if_needed() {
	if [ $(grep ^ /etc/apt/sources.list /etc/apt/sources.list.d/* | grep -v list.save | grep -v deb-src | grep deb | grep juju-ubuntu-stable | wc -l) -eq 0 ]; then
		echo "adding juju stable repository..."
		sudo add-apt-repository ppa:juju/stable
	fi
}

install_pkg_if_needed() {
	if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
		sudo apt install $1
	fi
}

show_help() {
    exec cat <<EOF
Usage: release_charm.sh [OPTIONS]

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

add_juju_repo_if_needed
install_pkg_if_needed charm
install_pkg_if_needed charm-tools

# clone charm from sources
[ -e $NAME ] || git clone $URL $NAME

# publish in store
charm login
VERSION=`charm push ./$NAME | grep -Po "(?<=$NAME-)\d+")`

# promote charm to all channels, grant permissions and set homepage and issues urls
charm release cs:~$OWNER/$NAME-$VERSION --channel edge
charm release cs:~$OWNER/$NAME-$VERSION --channel beta
charm release cs:~$OWNER/$NAME-$VERSION --channel candidate
charm release cs:~$OWNER/$NAME-$VERSION --channel stable

charm grant cs:~$OWNER/$NAME-$VERSION --acl read everyone

charm set cs:~$OWNER/$NAME --channel stable homepage=$HOMEPAGE
charm set cs:~$OWNER/$NAME --channel stable bugs-url=$ISSUES

echo "cs:~$OWNER/$NAME release finished Ok."
