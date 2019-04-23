#!/usr/bin/env bash
##############################################################################
# Auto complete for magento console
#
# Install a package bamarni/symfony-console-autocomplete for your user:
#   $ composer global require bamarni/symfony-console-autocomplete
# And bash complete:
#   $ yum install -y bash-completion
#
# References:
#   https://github.com/bamarni/symfony-console-autocomplete
#   https://www.cyberciti.biz/faq/fedora-redhat-scientific-linuxenable-bash-completion/
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __dir __file

how_help () {
  cat << EOF
Install Magento 2 binary file auto-completion.

OPTIONS
 -b FILE, --binary FILE
      Set path to binary file to put it into /usr/local/bin directory
EOF
}

read_params () {
  # Process args
  action=''
  if [[ -n "${1:-}" ]] && [[ "${1::1}" != '-' ]]; then
    action="$1"
    shift
  fi

  # Process options
  # validate and redefine options
  OPTS=`getopt -o vhn -l version,help,no-restart -- "$@"`
  eval set -- "${OPTS}"
  restart_on=1
  while true; do
    case "${1}" in
      -b|--binary)
        magento_bin=${2}
        shift 2
        ;;
      -d|--global-binary-dir)
        global_binary_dir=${2}
        shift 2
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      -\?)
        show_help
        exit 1
        ;;
      --)
        shift
        break
        ;;
      *)
        echo "${0}: unparseable option ${1}."
        exit 3
        ;;
    esac
  done

  rest_params=$@
}

sudo_cmd() {
  local docroot sud
  # use sudo if possible
  sud_cmd=$(sudo -h > /dev/null 2>&1 && echo sudo || true)

  docroot=${DOCROOT_DIR:-/var/www/html}

  # use only root or sudo
  if [ $(whoami) != 'root' ] && [ -z "${sud_cmd}" ]; then
    echo 'error: It cannot be done without root permissions. Seem you have no sudo. Login with root then.' > /dev/stderr
    exit 2
  fi
}

bash_completion_installed? () {
  if [ ${package_manager} == 'yum' ]; then
    ${sud} ${package_manager} list installed bash-completion
  elif [ ${package_manager} == 'apt-get' ]; then
    ${sud} dpkg -s bash-completion
  fi
}

install_bash_completion() {
  local package_manager=yum

  if ! ${package_manager} --help 2> /dev/null 1> /dev/null; then
    package_manager=apt-get
  fi
  if ! ${package_manager} --help 2> /dev/null 1> /dev/null; then
    echo 'error: Cannot find suitable package package manager. YUM and APT-GET does not work.' > /dev/stderr
    exit 2
  fi

  if ! bash_completion_installed? 1> /dev/null 2> /dev/null; then
    ${sud} ${package_manager} install -y bash-completion
  fi
}

install_symfony_autocomplete() {
  local sources_dir='/usr/share/symfony-autocomplete'
  local binary="${sources_dir}/vendor/bin/symfony-autocomplete" \
    link='/usr/bin/symfony-autocomplete' \
    composer_bin=${COMPOSER_BIN:-composer}

  if type symfony-autocomplete > /dev/null 2> /dev/null || [ -d ${link} ]; then
    # binary already declared
    return
  fi

  mkdir -p "${sources_dir}"
  ${composer_bin} "composer --working-dir=${sources_dir} require bamarni/symfony-console-autocomplete"

  ln -s ${binary} ${link}

  # set readable and accessible
  chmod +rX ${sources_dir}

  echo 'Installed binary:'
  ls -l ${link} | cut -d' ' -f9-
}

install_magento_bin() {
  if type magento > /dev/null 2> /dev/null || [[ -z "${magento_bin:-}" ]]; then
    # binary already declared
    return
  fi

  if [[ -f "${magento_bin}" ]]; then
    if [[ -d /usr/local/bin ]]; then
      link='/usr/bin/local/magento'
    elif [[ -d /usr/bin ]]; then
      link='/usr/bin/magento'
    elif [[ -d /bin ]]; then
      link='/bin/magento'
    elif [[ -d ~/bin ]]; then
      link='~/bin/magento'
    else
      echo "Cannot define binary directory. There is no path like: /usr/bin/local, /usr/bin, /bin, or ~/bin." > /dev/stderr
      return 2
    fi
  else
    echo "Magento 2 app-binary file ${magento_bin} not found." > /dev/stderr
    return 3
  fi

  if [[ -L ${link} ]]; then
    chmod +x ${link}
    # binary already declared
    return
  fi

  ln -s ${binary} ${link}

  echo 'Installed binary:'
  ls -l ${link} | cut -d' ' -f9-
}

install_complete_script() {
  if [ -f /etc/bash_completion.d/console ]; then
    return
  fi
  # Copy and load file for autocompletion
  ${sud} cp ${__dir}/autocomplete.sh /etc/bash_completion.d/console
  ${sud} chmod +r /etc/bash_completion.d/console
  echo 'Set auto-complete scripts to file: /etc/bash_completion.d/console'
}

install_autocomplete () {
  local sud package_manager

  sud="$(sudo_cmd)"

  install_bash_completion

  # not required installation
  # it's need only for generation "autocomplete" script
  #install_symfony_autocomplete

  install_magento_bin
  install_complete_script
}

install_autocomplete
