host_port() {
  local domain=${1} port=${2} forward_type=${3:-port}

  hash=$(echo -n ${domain} | openssl dgst -sha1 | sed 's/^.* //')

  if [ "${forward_type}" == 'port' ]; then
    base_port=$(( 1024 + 0x${hash:0:3} + 0x${hash:3:3} + 0x${hash:2:2} ))
    echo $(( ${base_port} + ${port} ))
  else
    if [ "${port}" == '22' ]; then
      # use 21 because VM SSH service takes 22
      port = 21
    fi
    echo 127.$((0x${hash:0:2}))'.'$((0x${hash:2:2}))'.'$((0x${hash:4:2}))':'${port}
  fi
}

# include predefined env variables
. ${__dir}/../global.env

vagrant_forward_type='port'

# use custom project name or generate it from parent directory name
[ -n "${M2SETUP_PROJECT}" ] && export M2SETUP_PROJECT=${M2SETUP_PROJECT} \
  || export M2SETUP_PROJECT=${M2SETUP_PROJECT:-$(echo ${__dir} | sed -r 's|.*/([^/]+)/bin$|\1|')}

[ -n "${M2SETUP_VIRTUAL_HOST:-}" ] && export M2SETUP_VIRTUAL_HOST=${M2SETUP_VIRTUAL_HOST} \
  || export M2SETUP_VIRTUAL_HOST=${M2SETUP_PROJECT}.cc

# generate docker image pefix (Docker does this automatically)
DOCKER_IMAGE_PREFIX=$(echo ${__dir} | sed -r 's|.*/([^/]+)/bin$|\1|' | tr -d '.-')

# PHP version
export M2SETUP_PHP=${M2SETUP_PHP}

# Generate environment variable for ports
# for "Host > VM > Docker" communications within different projects
export M2SETUP_PORT_22=$(host_port ${M2SETUP_VIRTUAL_HOST} 22 ${vagrant_forward_type})
export M2SETUP_PORT_80=$(host_port ${M2SETUP_VIRTUAL_HOST} 80 ${vagrant_forward_type})
export M2SETUP_PORT_443=$(host_port ${M2SETUP_VIRTUAL_HOST} 443 ${vagrant_forward_type})
export M2SETUP_PORT_3306=$(host_port ${M2SETUP_VIRTUAL_HOST} 3306 ${vagrant_forward_type})
export M2SETUP_PORT_9000=$(host_port ${M2SETUP_VIRTUAL_HOST} 9000 ${vagrant_forward_type})

dev_file_option=''
if [ -f ${__dir}/../docker-compose.dev.yml ]; then
  dev_file_option="--file ${__dir}/../docker-compose.dev.yml"
fi
