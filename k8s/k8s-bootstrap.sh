#!/bin/bash -e
#
# Copyright (C) 2018 Roberto Mier Escandon <rmescandon@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

master="kmaster"
slave="kslave"
n=0
no_master=

show_help() {
    exec cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap k8s

optional arguments:
  -h, --help            Show this help message and exit
  -m, --master			Name of the master machine
  -s, --slave			Prefix of the slave machine names
  -n, --num-slaves 		Number of slaves to create
  --no-master			Skip master creation

EOF
}
while [ -n "$1" ]; do
	case "$1" in
		-h|--help)
			show_help
			exit
			;;
		-m=*|--master=*)
			master=${1#*=}
			shift
			;;
		-m|--master)
			master=$2
			shift 2
			;;
		-s=*|--slave=*)
			slave=${1#*=}
			shift
			;;
		-s|--slave)
			slave=$2
			shift 2
			;;
		--no-master)
			no_master=1
			shift
			;;
		-n=*|--num-slaves=*)
			n=${1#*=}
			shift
			;;
		-n|--num-slaves)
			n=$2
			shift 2
			;;
		--) # end argument parsing
      		shift
      		break
      		;;
      	-*|--*=) # unsupported flags
	    	echo "Error: Unsupported flag $1" >&2
	      	exit 1
	      	;;
		*)
			echo "Invalid parameter"
			exit 1
			;;
	esac
done

# Create master
if [ -z "$no_master" ]; then
	"$(dirname "$0")"/k8s-new-node.sh "$master" master
fi

# Fetch credentials from master to join the rest of the nodes
exec_on_master="multipass exec $master --"
master_ip=$($exec_on_master hostname -I | cut -f 1 -d ' ')
token=$($exec_on_master kubeadm token list | grep -v ^TOKEN | cut -d' ' -f1 | xargs)
ca_cert=$($exec_on_master openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')

i=0
while [ "$i" -lt "$n" ]; do
	"$(dirname "$0")"/k8s-new-node.sh "$slave-$i" --master-ip="$master_ip" --token="$token" --ca-cert="$ca_cert"
	let i=i+1
done

# Update /etc/hosts of master and slaves
"$(dirname "$0")"/k8s-set-hosts.sh
