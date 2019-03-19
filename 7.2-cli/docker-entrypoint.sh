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

    DOCKER_UID=`stat -c "%u" $MAGENTO_ROOT`
    DOCKER_GID=`stat -c "%g" $MAGENTO_ROOT`

    INCUMBENT_USER=`getent passwd $DOCKER_UID | cut -d: -f1`
    INCUMBENT_GROUP=`getent group $DOCKER_GID | cut -d: -f1`

    echo "Docker: uid = $DOCKER_UID, gid = $DOCKER_GID"
    echo "Incumbent: user = $INCUMBENT_USER, group = $INCUMBENT_GROUP"

    # Once we've established the ids and incumbent ids then we need to free them
    # up (if necessary) and then make the change to www-data.

    [ -n "${INCUMBENT_USER}" ] && usermod -u 99$DOCKER_UID $INCUMBENT_USER
    usermod -u $DOCKER_UID www-data

    [ -n "${INCUMBENT_GROUP}" ] && groupmod -g 99$DOCKER_GID $INCUMBENT_GROUP
    groupmod -g $DOCKER_GID www-data
fi

# Ensure our Magento directory exists
mkdir -p $MAGENTO_ROOT
chown www-data:www-data $MAGENTO_ROOT

CRON_LOG=/var/log/cron.log

# Setup Magento cron
echo "* * * * * www-data /usr/local/bin/php ${MAGENTO_ROOT}/bin/magento cron:run | grep -v \"Ran jobs by schedule\" >> ${MAGENTO_ROOT}/var/log/magento.cron.log" > /etc/cron.d/magento
echo "* * * * * www-data /usr/local/bin/php ${MAGENTO_ROOT}/update/cron.php >> ${MAGENTO_ROOT}/var/log/update.cron.log" >> /etc/cron.d/magento
echo "* * * * * www-data /usr/local/bin/php ${MAGENTO_ROOT}/bin/magento setup:cron:run >> ${MAGENTO_ROOT}/var/log/setup.cron.log" >> /etc/cron.d/magento

# Get rsyslog running for cron output
touch $CRON_LOG
echo "cron.* $CRON_LOG" > /etc/rsyslog.d/cron.conf
service rsyslog start

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

# Configure composer
[ -n "${COMPOSER_GITHUB_TOKEN:-}" ] && \
  composer config --global github-oauth.github.com ${COMPOSER_GITHUB_TOKEN}

[ -n "${COMPOSER_MAGENTO_USERNAME:-}" ] && \
  composer config --global http-basic.repo.magento.com \
    ${COMPOSER_MAGENTO_USERNAME} ${COMPOSER_MAGENTO_PASSWORD}

[ -n "${COMPOSER_BITBUCKET_KEY:-}" ] && [ -n "${COMPOSER_BITBUCKET_SECRET:-}" ] && \
  composer config --global bitbucket-oauth.bitbucket.org \
    ${COMPOSER_BITBUCKET_KEY} ${COMPOSER_BITBUCKET_SECRET}

[ -n "${COMPOSER_PRIVATE_USERNAME:-}" ] && \
  [ -n "${COMPOSER_PRIVATE_PASSWORD:-}" ] && \
  [ -n "${COMPOSER_PRIVATE_URL:-}" ] && \
    composer config --global repositories.private composer ${COMPOSER_PRIVATE_URL} && \
    composer config --global http-basic.$(echo ${COMPOSER_PRIVATE_URL} | sed -r 's#(^https?://)([^/]+)(.*)#\2#g') \
      ${COMPOSER_PRIVATE_USERNAME} ${COMPOSER_PRIVATE_PASSWORD}

exec "$@"

