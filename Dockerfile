FROM debian:jessie

MAINTAINER Caleb Land <caleb@land.fm>

ENV DOCKER_HELPERS_VERSION=1.0

# Download our docker helpers
ADD https://github.com/caleb/docker-helpers/releases/download/v${DOCKER_HELPERS_VERSION}/helpers-v${DOCKER_HELPERS_VERSION}.tar.gz /tmp/helpers.tar.gz

# Install the docker helpers
RUN mkdir -p /helpers \
&&  tar xzf /tmp/helpers.tar.gz -C / \
&&  rm /tmp/helpers.tar.gz

# Install the base system
RUN /bin/bash /helpers/install_base.sh

RUN apt-get update \
&&  apt-get install -y opendkim opendkim-tools openssl \
&&  rm -rf /var/lib/apt/lists/* \
&&  rm /etc/opendkim.conf \
&&  mkdir -p /etc/opendkim

COPY opendkim.conf.mo     /etc/opendkim.conf.mo
COPY docker-entrypoint.sh /entrypoint.sh

Add sv /etc/service

VOLUME /var/run/opendkim
EXPOSE 8891

ENTRYPOINT ["/entrypoint.sh"]

CMD ["runsvdir", "/etc/service"]
