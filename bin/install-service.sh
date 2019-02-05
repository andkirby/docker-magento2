#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __dir __file

cat <<- EOB > /etc/systemd/system/project.service

[Unit]
Description=Default web project: $(cd ${__dir}/..; basename ${PWD})
After=network.target

[Service]
Type=simple
ExecStart=${__dir}/docker-compose-local-varnish up
TimeoutStartSec=1

[Install]
WantedBy=default.target
EOB

systemctl daemon-reload
systemctl enable project.service
systemctl start project.service
