FROM python:2.7

# declare your connection env vars
ENV PAGEKITE_HOST=""
ENV PAGEKITE_SECRET=""
# internal hostname of nginx container
ENV M2SETUP_WEB_HOST=""
# internal hostname of nginx container
ENV M2SETUP_WEB_HOST=""

ADD https://pagekite.net/pk/pagekite.py /bin/pagekite.py
ADD bin/docker-environment /bin/

RUN chmod +x /bin/pagekite.py /bin/docker-environment

ENTRYPOINT ["bash", "/bin/docker-environment"]
