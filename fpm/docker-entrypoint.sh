#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

[ "${DEBUG:-}" = "true" ] && set -x

# If asked, we'll ensure that the www-data is set to the same uid/gid as the
# mounted volume.  This works around permission issues with virtualbox shared
# folders.
update_uid() {
  echo "Updating www-data uid and gid"

  local docker_uid=${DOCKER_UID:-$(stat -c "%u" ${MAGENTO_ROOT})} \
        docker_gid=${DOCKER_GID:-$(stat -c "%g" ${MAGENTO_ROOT})}
  local incumbent_user=$(getent passwd ${docker_uid} | cut -d: -f1 || true) \
        incumbent_group=$(getent group ${docker_gid} | cut -d: -f1 || true)

  [[ -n "${incumbent_user:-}" ]] && echo "Incumbent: user = ${incumbent_user}" || true
  [[ -n "${incumbent_group:-}" ]] && echo "Incumbent: group = ${incumbent_group}" || true

  # Once we've established the ids and incumbent ids then we need to free them
  # up (if necessary) and then make the change to www-data.

  if [[ -n "${incumbent_user:-}" ]] && [[ "${incumbent_user:-}" != 'www-data' ]]; then
      usermod -u 99${docker_uid} ${incumbent_user}
  fi
  if [[ -n "${incumbent_group:-}" ]] && [[ "${incumbent_group:-}" != 'www-data' ]]; then
      groupmod -g 99${docker_gid} ${incumbent_group}
  fi

  usermod -u ${docker_uid} www-data
  groupmod -g ${docker_gid} www-data
}

# Code #########################################################################

if [[ "${UPDATE_UID_GID:-}" = 'true' ]]; then
  update_uid
fi

# Ensure our Magento directory exists
mkdir -p $MAGENTO_ROOT
chown www-data:www-data $MAGENTO_ROOT

##
# Set up forwarding emails into mailcatcher container
#
# https://stackoverflow.com/a/28467090
#
if [ "${USE_MAILCATCHER:-}" == "true" ]; then
  sed -ri "s/mailhub=.*/mailhub=${SSMTP_SMTP_SERVER:-mailcatcher:1025}/" /etc/ssmtp/ssmtp.conf

  if [[ -n "${SSMTP_REWRITE_DOMAIN:-}" ]]; then
    sed -ri "s/[#]?rewriteDomain=.*/rewriteDomain=${SSMTP_REWRITE_DOMAIN}/" /etc/ssmtp/ssmtp.conf
    sed -ri "s/[#]?FromLineOverride=.*/FromLineOverride=YES/" /etc/ssmtp/ssmtp.conf
  fi
else
  # enable using default 25 port
  sed -ri "s/mailhub=.*/mailhub=/" /etc/ssmtp/ssmtp.conf
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

