FROM tiredofit/alpine:3.8
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

ENV ENABLE_CRON=FALSE \
    ENABLE_SMTP=FALSE \
    RABBITMQ_LOGS=- \
    RABBITMQ_SASL_LOGS=- \
    RABBITMQ_HOME=/opt/rabbitmq \
    GPG_KEY=0A9AF2115F4687BD29803A206B73A36E6026DFCA \
    RABBITMQ_VERSION=3.7.7 \
    HOME=/var/lib/rabbitmq \
    ZABBIX_HOSTNAME=rabbitmq-app
ENV PATH=$RABBITMQ_HOME/sbin:$PATH

## RabbitMQ Setup
# Add Users First before anything else installed
RUN set -x && \
    addgroup -g 5672 rabbitmq && \
    adduser -S -D -G rabbitmq -u 5672 -h /var/lib/rabbitmq rabbitmq && \

# grab su-exec for easy step-down from root
    apk update && \
    apk add --no-cache \
        'su-exec>=0.2' \
         && \
# SelfDesign Dependencies
    apk add -t .rabbitmq-run-deps \
		erlang-asn1 \
		erlang-hipe \
		erlang-crypto \
		erlang-eldap \
		erlang-inets \
		erlang-mnesia \
		erlang \
		erlang-os-mon \
		erlang-public-key \
		erlang-sasl \
		erlang-ssl \
		erlang-syntax-tools \
		erlang-xmerl \
        python \
		&& \

	apk add --no-cache --virtual .rabbitmq-build-deps \
		ca-certificates \
		gnupg \
		libressl \
		tar \
		xz \
	    && \

	wget -O rabbitmq-server.tar.xz "https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.7.7/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz" && \
	mkdir -p "$RABBITMQ_HOME" && \
	tar --extract --verbose --file rabbitmq-server.tar.xz --directory "$RABBITMQ_HOME" --strip-components 1 && \
	rm rabbitmq-server.tar.xz && \
	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults" && \
	sed -ri 's!^(SYS_PREFIX=).*$!\1!g' "$RABBITMQ_HOME/sbin/rabbitmq-defaults" && \
	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults" && \
    
#Cleanup
	apk del .rabbitmq-build-deps && \
        rm -rf /var/cache/apk/* && \

## Rabbit MQ Setup
    mkdir -p /var/lib/rabbitmq /etc/rabbitmq && \
    chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq && \
    chmod -R 777 /var/lib/rabbitmq /etc/rabbitmq && \
    ln -sf /var/lib/rabbitmq/.erlang.cookie /root/ && \
    ln -sf "$RABBITMQ_HOME/plugins" /plugins && \
    $RABBITMQ_HOME/sbin/rabbitmq-plugins enable --offline rabbitmq_management

## Add Assets
ADD install /

### Zabbix Setup 
RUN chmod +x /etc/zabbix/zabbix_agentd.conf.d/*.sh && \
    chmod +x /etc/zabbix/zabbix_agentd.conf.d/*.py && \
    mv /etc/zabbix/zabbix_agentd.conf.d/rab.auth /etc/zabbix/zabbix_agentd.conf.d/.rab.auth

## Volume Setup
VOLUME /var/lib/rabbitmq

## Networking Setup
EXPOSE 4369 5671 5672 25672 15671 15672
