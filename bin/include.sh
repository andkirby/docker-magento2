####################################################################
############# Prepare env variables for ports forwarding ############
####################################################################

##
# Generate a port map based upon a domain name
#
# host_port KEYWORD TARGET_PORT FORWARD_TYPE[=normal] STANDARD_PORT[=0]
#
# KEYWORD - keyword for port/ip generation, usually hostname or project name
# TARGET_PORT - target port in a container
# FORWARD_TYPE - target port in a container
# Use normal ports instead of generated ones
#
# Generate ports map
# example for host m23.cc:
#    4693:80, 5056:443
#DOCKER_FORWARDING_TYPE=ports
#
# Generate IP map
# Example for host m23.cc:
#    127.56.22.34:80:80, 127.56.22.34:443:443
#DOCKER_FORWARDING_TYPE=ip
#
# ENV vars:
#    DOCKER_FORWARDING_SSH_PORT - it used to rewrite 22 port by a custom one
#
host_port() {
  local keyword=${1} target_port=${2} forward_type=${3:-normal} standard_port=${4:-0}}

  hash=$(echo -n ${keyword} | openssl dgst -sha1 | sed 's/^.* //')

  if [ "${forward_type:-}" == 'normal' ]; then
    # ignore generating port number, just return the same port

    if [ -n "${DOCKER_FORWARDING_SSH_PORT:-}" ]; then
      # use custom port if your host takes 22
      target_port=$(( "${DOCKER_FORWARDING_SSH_PORT:-}" + 0 ))
    fi

    echo ${target_port}

  elif [[ "${forward_type}" == 'port' ]]; then
    base_port=$(( 1024 + 0x${hash:0:3} + 0x${hash:3:3} + 0x${hash:2:2} ))
    echo $(( ${base_port} + ${target_port} ))

  elif [[ "${forward_type}" == 'ip' ]]; then
    if [ -n "${DOCKER_FORWARDING_SSH_PORT:-}" ]; then
      # use custom port if your host takes 22
      target_port=$(( "${DOCKER_FORWARDING_SSH_PORT:-}" + 0 ))
    fi

    echo 127.$((0x${hash:0:2}))'.'$((0x${hash:2:2}))'.'$((0x${hash:4:2}))':'${target_port}
  else
    echo "Uknown forward type ${forward_type}."
  fi
}

# include predefined env variables
. ${__dir}/../global.env

# use custom project name or generate it from parent directory name
[[ -n "${M2SETUP_PROJECT}" ]] && export M2SETUP_PROJECT=${M2SETUP_PROJECT} \
  || export M2SETUP_PROJECT=${M2SETUP_PROJECT:-$(echo ${__dir} | sed -r 's|.*/([^/]+)/bin$|\1|')}

[[ -n "${M2SETUP_VIRTUAL_HOST:-}" ]] && export M2SETUP_VIRTUAL_HOST=${M2SETUP_VIRTUAL_HOST} \
  || export M2SETUP_VIRTUAL_HOST=${M2SETUP_PROJECT}.cc

# generate docker image pefix (Docker does this automatically)
export DOCKER_IMAGE_PREFIX=$(echo ${__dir} | sed -r 's|.*/([^/]+)/bin$|\1|' | tr -d '.-')

# PHP version
export M2SETUP_PHP=${M2SETUP_PHP}

# Generate environment variable for ports
# for "Host > VM > Docker" communications within different projects
# ssh port
export M2SETUP_PORT_22=$(host_port ${M2SETUP_VIRTUAL_HOST} 22 "${DOCKER_FORWARDING_TYPE:-normal}")
# http ports
export M2SETUP_PORT_80=$(host_port ${M2SETUP_VIRTUAL_HOST} 80 "${DOCKER_FORWARDING_TYPE:-normal}")
export M2SETUP_PORT_8080=$(host_port ${M2SETUP_VIRTUAL_HOST} 8080 "${DOCKER_FORWARDING_TYPE:-normal}")
export M2SETUP_PORT_443=$(host_port ${M2SETUP_VIRTUAL_HOST} 443 "${DOCKER_FORWARDING_TYPE:-normal}")
# mysql port
export M2SETUP_PORT_3306=$(host_port ${M2SETUP_VIRTUAL_HOST} 3306 "${DOCKER_FORWARDING_TYPE:-normal}")
# xdebug ports
export M2SETUP_PORT_9000=$(host_port ${M2SETUP_VIRTUAL_HOST} 9000 "${DOCKER_FORWARDING_TYPE:-normal}")
export M2SETUP_PORT_9001=$(host_port ${M2SETUP_VIRTUAL_HOST} 9001 "${DOCKER_FORWARDING_TYPE:-normal}")

dev_file_option=''
if [[ -f ${__dir}/../docker-compose.dev.yml ]]; then
  dev_file_option="--file ${__dir}/../docker-compose.dev.yml"
fi
