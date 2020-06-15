FROM nginx:1

MAINTAINER Nick Jones <nick@nicksays.co.uk>

ADD etc/vhost.conf /etc/nginx/conf.d/default.conf
COPY etc/certs/ /etc/nginx/ssl/

EXPOSE 443

ENV PHP_UPLOAD_MAX_FILESIZE 64M
ENV FPM_HOST fpm
ENV FPM_PORT 9000
ENV MAGENTO_ROOT /var/www/magento
ENV MAGENTO_RUN_MODE developer
ENV DEBUG false


################# letsencrypt #######################
# Installing LetsEncrypt certificate

# Set your host as an argument
# yourkite.pagekite.me
ENV LETSENCRYPT_HOST=''
# admin@example.com
ENV LETSENCRYPT_EMAIL=''

RUN true \
  && apt-get update -y \
  && apt-get install -y python3-acme python3-certbot \
      python3-mock \
      python3-openssl \
      python3-pkg-resources \
      python3-pyparsing \
      python3-zope.interface \
      python-certbot-nginx

VOLUME /etc/letsencrypt/

# other installation is expected in the docker-environment script
################# EOB letsencrypt ###################

ADD bin/* /usr/local/bin/
RUN ["chmod", "+x", "/usr/local/bin/docker-environment"]

ENTRYPOINT ["/usr/local/bin/docker-environment"]
CMD ["nginx", "-g", "daemon off;"]
