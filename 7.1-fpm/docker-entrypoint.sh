#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

[ "${DEBUG:-}" = "true" ] && set -x

# If asked, we'll ensure that the www-data is set to the same uid/gid as the
# mounted volume.  This works around permission issues with virtualbox shared
# folders.
if [[ "${UPDATE_UID_GID:-}" = "true" ]]; then
    echo "Updating www-data uid and gid"

    if [[ -z "${DOCKER_UID:-}" ]]; then
      DOCKER_UID=`stat -c "%u" ${MAGENTO_ROOT}`
    fi
    if [[ -z "${DOCKER_GID:-}" ]]; then
      DOCKER_GID=`stat -c "%g" ${MAGENTO_ROOT}`
    fi

    INCUMBENT_USER=`getent passwd $DOCKER_UID | cut -d: -f1`
    INCUMBENT_GROUP=`getent group $DOCKER_GID | cut -d: -f1`

    echo "Docker: uid = $DOCKER_UID, gid = $DOCKER_GID"
    echo "Incumbent: user = $INCUMBENT_USER, group = $INCUMBENT_GROUP"

    # Once we've established the ids and incumbent ids then we need to free them
    # up (if necessary) and then make the change to www-data.

    [ -n "${INCUMBENT_USER:-}" ] && usermod -u 99$DOCKER_UID $INCUMBENT_USER
    usermod -u $DOCKER_UID www-data

    [ -n "${INCUMBENT_GROUP:-}" ] && groupmod -g 99$DOCKER_GID $INCUMBENT_GROUP
    groupmod -g $DOCKER_GID www-data
fi

# Ensure our Magento directory exists
mkdir -p $MAGENTO_ROOT
chown www-data:www-data $MAGENTO_ROOT

# Configure Sendmail if required
if [ "${ENABLE_SENDMAIL:-}" == "true" ]; then
    /etc/init.d/sendmail start
fi

# Substitute in php.ini values
[ -n "${PHP_MEMORY_LIMIT:-}" ] \
  && sed -i "s/memory_limit ?=.*/memory_limit = ${PHP_MEMORY_LIMIT}/" \
        /usr/local/etc/php/conf.d/zz-magento.ini

[ -n "${PHP_UPLOAD_MAX_FILESIZE:-}" ] \
  && sed -i "s/upload_max_filesize ?=.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
        /usr/local/etc/php/conf.d/zz-magento.ini

# Enable Xdebug
[ "${PHP_ENABLE_XDEBUG:-}" = "true" ] && xd_swi on || xd_swi off

# Configure PHP-FPM
[ -n "${MAGENTO_RUN_MODE:-}" ] \
  && sed -i "s/env[MAGE_MODE] ?=.*/env[MAGE_MODE] = ${MAGENTO_RUN_MODE}/" \
        /usr/local/etc/php-fpm.conf

exec "$@"

