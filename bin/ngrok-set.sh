#!/usr/bin/env bash

###################################
# Try to start ngrok as a service
###################################

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __dir __file

target_host=${1}

##
# E.g: ngrok_tunnel_host 0.0.0.0:1234 https
ngrok_tunnel_host() {
  local filter_host=${1} \
    type=${2:-https}
  python ${__dir}/ngrok-tunnels.py ${filter_host}
}

# fetch a given hostname
ngrok_url=$(ngrok_tunnel_host ${target_host} || true)

# start new tunnel if it wasn't started
if [[ -z "${ngrok_url}" ]]; then
#  echo $(nohup ngrok http ${app_host} &) > /dev/null
  bash ${__dir}/ngrok-run.sh ${target_host} > /dev/null || true

  # sleep to allow nohup put its content to output
  sleep 2

  ngrok_url=$(ngrok_tunnel_host ${target_host})
else
  echo "notice: ngrok tunnel already in progress for ${target_host}!" > /dev/stderr
fi

if [[ -z "${ngrok_url}" ]]; then
  echo "error: Could not get ngrok tunnel URL." > /dev/stderr
  exit 4
fi

echo ${ngrok_url}
