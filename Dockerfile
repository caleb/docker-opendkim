FROM debian:jessie

MAINTAINER Caleb Land <caleb@land.fm>

ADD https://github.com/caleb/docker-helpers/archive/master.tar.gz /tmp/helpers.tar.gz
ADD https://github.com/caleb/syslog_forwarder/releases/download/1.0/syslog_forwarder-linux-amd64-v1.0.tar.gz /tmp/syslog_forwarder.tar.gz
ADD https://raw.githubusercontent.com/caleb/mo/master/mo /usr/local/bin/mo

RUN mkdir -p /helpers \
&&  tar xzf /tmp/helpers.tar.gz -C / docker-helpers-master/helpers \
&&  mv /docker-helpers-master/helpers/* /helpers \
&&  rm -rf /docker-helpers-master \
&&  rm /tmp/helpers.tar.gz \
&&  chmod +x /usr/local/bin/mo \
&&  tar xzf /tmp/syslog_forwarder.tar.gz -C /usr/local/bin \
&&  rm /tmp/syslog_forwarder.tar.gz

RUN apt-get update \
&&  apt-get install -y opendkim opendkim-tools openssl runit \
&&  rm /etc/opendkim.conf \
&&  mkdir -p /etc/opendkim

COPY opendkim.conf.mo     /etc/opendkim.conf.mo
COPY docker-entrypoint.sh /entrypoint.sh

Add sv /etc/service

VOLUME /var/run/opendkim
EXPOSE 8891

ENTRYPOINT ["/entrypoint.sh"]

CMD ["runsvdir", "/etc/service"]
