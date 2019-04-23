#!/usr/bin/env bash
##############################################################################
# Regenerate packages.json on change generate.json file.                    ##
##############################################################################
# Please run run-watch.sh instead this one.                                 ##
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __dir __file

if [[ -z "${1:-}" ]]; then
  echo 'error: Please define watch file/s (directory/es) as a first argument.' > /dev/stderr && exit 3
fi
if [[ -z "${2:-}" ]]; then
  echo 'error: Please define a trigger-command as a second argument.' > /dev/stderr && exit 3
fi

# Check installed "inotifywait" tools
type inotifywait 2> /dev/null > /dev/null || sudo yum install -y inotify-tools

watch_file=${1}
watch_exec=${2}

while inotifywait -e close_write ${watch_file}; do
  ${watch_exec}
done
