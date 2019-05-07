#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
#set -o xtrace

[[ "${DEBUG:-}" = "true" ]] && set -o xtrace

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

##
# File system initiating
#
files_init() {
  # Ensure our Magento directory exists
  mkdir -p ${MAGENTO_ROOT}

  chown www-data:www-data ${MAGENTO_ROOT}
  chown www-data:www-data -R /var/www/.composer/cache
}

##
# Setup cron for magento
#
setup_cron() {
  CRON_LOG=/var/log/cron.log

  # Setup Magento cron
  cat <<-SHELL > /etc/cron.d/magento
# crontab -e
SHELL=/bin/bash
MAILTO=''

${CRON_SCHEDULE:-'* * * * *'} www-data /usr/local/bin/php ${MAGENTO_ROOT}/bin/magento cron:run | grep -v \"Ran jobs by schedule\" >> ${MAGENTO_ROOT}/var/log/magento.cron.log
${CRON_SCHEDULE:-'* * * * *'} www-data /usr/local/bin/php ${MAGENTO_ROOT}/update/cron.php >> ${MAGENTO_ROOT}/var/log/update.cron.log
${CRON_SCHEDULE:-'* * * * *'} www-data /usr/local/bin/php ${MAGENTO_ROOT}/bin/magento setup:cron:run >> ${MAGENTO_ROOT}/var/log/setup.cron.log
SHELL

  # Get rsyslog running for cron output
  touch ${CRON_LOG}
  echo "cron.* ${CRON_LOG}" > /etc/rsyslog.d/cron.conf
  service rsyslog start
}

##
# Setup PHP ini files
#
setup_php_ini() {
  # Substitute in php.ini values
  [[ -n "${PHP_MEMORY_LIMIT:-}" ]] \
    && sed -i "s/memory_limit ?=.*/memory_limit = ${PHP_MEMORY_LIMIT}/" \
          /usr/local/etc/php/conf.d/zz-magento.ini

  [[ -n "${PHP_UPLOAD_MAX_FILESIZE:-}" ]] \
    && sed -i "s/upload_max_filesize ?=.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
          /usr/local/etc/php/conf.d/zz-magento.ini

  # On/Off Xdebug
  [[ "${PHP_ENABLE_XDEBUG:-}" = "true" ]] && xd_swi on || true
  [[ "${PHP_ENABLE_XDEBUG:-}" = "false" ]] && xd_swi off || true
}

##
# Set up forwarding emails into mailcatcher container
#
# https://stackoverflow.com/a/28467090
#
setup_mailcatcher() {
  if [[ "${USE_MAILCATCHER:-}" = 'true' ]]; then
    sed -ri "s/mailhub=.*/mailhub=${MAILCATCHER_HOST:-mailcatcher:1025}/" /etc/ssmtp/ssmtp.conf

    if [[ "${MAILCATCHER_REWRITE_DOMAIN:-1}" = '1' ]]; then
      sed -ri "s/[#]?rewriteDomain=.*/rewriteDomain=${MAILCATCHER_REWRITE_DOMAIN}/" /etc/ssmtp/ssmtp.conf
      sed -ri "s/[#]?FromLineOverride=.*/FromLineOverride=YES/" /etc/ssmtp/ssmtp.conf
    fi
  else
    # enable using default 25 port
    sed -ri "s/mailhub=.*/mailhub=/" /etc/ssmtp/ssmtp.conf
  fi
}

##
# Setup composer keys
#
setup_composer() {
  #disable pipefail
  set +o pipefail

  # Configure composer
  [[ -n "${COMPOSER_GITHUB_TOKEN:-}" ]] && \
    composer config --global github-oauth.github.com ${COMPOSER_GITHUB_TOKEN}

  [[ -n "${COMPOSER_MAGENTO_USERNAME:-}" ]] && \
    composer config --global http-basic.repo.magento.com \
      ${COMPOSER_MAGENTO_USERNAME} ${COMPOSER_MAGENTO_PASSWORD}

  [[ -n "${COMPOSER_BITBUCKET_KEY:-}" ]] && [[ -n "${COMPOSER_BITBUCKET_SECRET:-}" ]] && \
    composer config --global bitbucket-oauth.bitbucket.org \
      ${COMPOSER_BITBUCKET_KEY} ${COMPOSER_BITBUCKET_SECRET}

  [[ -n "${COMPOSER_PRIVATE_USERNAME:-}" ]] && \
    [[ -n "${COMPOSER_PRIVATE_PASSWORD:-}" ]] && \
    [[ -n "${COMPOSER_PRIVATE_URL:-}" ]] && \
      composer config --global repositories.private composer ${COMPOSER_PRIVATE_URL} && \
      composer config --global http-basic.$(echo ${COMPOSER_PRIVATE_URL} | sed -r 's#(^https?://)([^/]+)(.*)#\2#g') \
        ${COMPOSER_PRIVATE_USERNAME} ${COMPOSER_PRIVATE_PASSWORD}

  #enable pipefail
  set -o pipefail
}

##
# Start sendmail service
#
setup_sendmail() {
  /etc/init.d/sendmail start
}

################################################################################
### Code scenario ###

if [[ "${UPDATE_UID_GID:-}" = 'true' ]]; then
  update_uid
fi

files_init

# Magento cron setup
#setup_cron

# Set up forwarding emails into mailcatcher
setup_mailcatcher

setup_php_ini
setup_composer

${@}

