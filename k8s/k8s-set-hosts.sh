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

existing_machines=$(multipass list --format csv | grep -v ^Name | sed 's/LTS//g' | xargs)

names=()
ips=()

for machine in $existing_machines; do
	tokens=()
	for token in $(echo $machine | sed -e "s/,/ /g"); do
		tokens+=("$token")
	done

	# Consider machine only if running
	if [ "${tokens[1]}" != "RUNNING" ]; then
		continue
	fi

	names+=(${tokens[0]})
	ips+=(${tokens[2]})
done

# Update /etc/hosts
for index in ${!names[@]}; do
	current="${names[$index]}"

	for i in ${!names[@]}; do
		# Add to /etc/hosts of current the ip hostname of any got machine if not existing yet
		set +e
		multipass exec "$current" cat /etc/hosts | grep -v '^#' | grep -q "${ips[$i]} ${names[$i]}"
		if [ $? -ne 0 ]; then 
			set -e
			multipass exec "$current" -- sudo sh -c "echo \"${ips[$i]} ${names[$i]}\" >> /etc/hosts"
		fi
		set -e
	done
done
