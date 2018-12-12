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

name=
role=
token=
ca_cert=
master_ip=

show_help() {
    exec cat <<EOF
Usage: $(basename "$0") [NAME] ([ROLE])

Creates a k8s node of the specified role (master/slave)

optional arguments:
  -h, --help                    Show this help message and exit
  -t, --token 					Token for slaves to join the cluster
  -c, --ca-cert                 Cluster CA certificate, needed for slaves to join the cluster
  -m, --master-ip				IP address of the master node. Needed for slaves to join to the cluster
EOF
}

positional_params=
while [ -n "$1" ]; do
	case "$1" in
		-h|--help)
			show_help
			exit
			;;
		-t=*|--token=*)
			token=${1#*=}
			shift
			;;
		-t|--token)
			token=$2
			shift 2
			;;
		-c=*|--ca-cert=*)
			ca_cert=${1#*=}
			shift
			;;
		-c|--ca-cert)
			ca_cert=$2
			shift 2
			;;
		-m=*|--master-ip=*)
			master_ip=${1#*=}
			shift
			;;
		-m|--master-ip)
			master_ip=$2
			shift 2
			;;
		-*|--*=) # unsupported flags
	    	echo "Error: Unsupported flag $1" >&2
	      	exit 1
	      	;;
	    *) # preserve positional arguments
      		positional_params="$positional_params $1"
      		shift
      		;;
	esac
done

# set positional arguments in their proper place
eval set -- "$positional_params"

for p in $(echo $positional_params | xargs); do
	if [ -z "$name" ]; then
		name="$p"
	elif [ -z "$role" ]; then
		role="$p"
	fi
done

if [ -z "$name" ]; then
	echo "A name for the machine is mandatory"
	exit 1
fi

if [ -z "$role" ]; then
	role="slave"
fi

if [[ "$role" = "slave"  && (-z "$token" || -z "$ca_cert" || -z "$master_ip") ]]; then
	echo "Master IP, token and ca cert are mandatory for slaves"
	exit 1
fi

multipass launch -n "$name" -c 2 -m 2G x

# $@ command to be executed on multipass machine
root_exec() {
	multipass exec "$name" -- sudo sh -c "$@"
}

do_exec() {
	multipass exec "$name" -- "$@"
}

# Install docker
root_exec "swapoff -a"
root_exec "apt install apt-transport-https ca-certificates curl software-properties-common -y"
root_exec "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -"
root_exec "add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\""
root_exec "apt update -y"
root_exec "apt upgrade -y"
root_exec "apt install docker-ce -y"

# Install kubernetes
root_exec "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
root_exec "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | tee /etc/apt/sources.list.d/kubernetes.list"
root_exec "apt update -y"
root_exec "apt upgrade -y"
root_exec "apt install kubelet kubeadm kubectl -y"

if [ "$role" = "master" ]; then
	ip=$(do_exec hostname -I | cut -f 1 -d ' ')
	cidr="$(cat /var/snap/multipass/common/data/multipassd/network/multipass_subnet)".0/24

	root_exec "kubeadm init --apiserver-advertise-address=$ip --pod-network-cidr=$cidr --ignore-preflight-errors=all"

	# configure kubectl tool
	do_exec mkdir -p /home/multipass/.kube
	root_exec "cp -fi /etc/kubernetes/admin.conf /home/multipass/.kube/config"
	root_exec "chown $(id -u):$(id -g) /home/multipass/.kube/config"

	# show status
	do_exec kubectl get nodes
elif [ "$role" = "slave" ]; then
	# slave...
	root_exec "kubeadm join --token $token $master_ip:6443 --discovery-token-ca-cert-hash sha256:$ca_cert"
else
	echo "Not a valid machine role"
	exit 1
fi

# aliases for k8s commands into the node
aliases=("kc=kubectl" "ka=kubeadm" "kl=kubelet")
for alias in ${aliases[@]}; do
	multipass exec "$name" -- sh -c "echo alias $alias >> /home/multipass/.bashrc"
done
