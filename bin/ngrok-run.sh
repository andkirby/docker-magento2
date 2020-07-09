#!/usr/bin/env bash

################################
# Start ngrok as a service
################################

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __dir __file

nohup ngrok start --all &

########################################################
# Expected configuration in ~/.ngrok2/ngrok.yml
#
# authtoken: XXXXXXXXXXXXXXXXXXXXXXXX
# web_addr: 0.0.0.0:4040
# region: eu
# tunnels:
#   mail:
#     addr: 12693 # <-- service mailcatcher 8025 port
#     proto: http
#   app:
#     addr: 4693 # <-- service varnish 80 port
#     proto: http
########################################################
