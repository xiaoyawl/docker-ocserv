FROM benyoo/alpine:3.4.20160812

MAINTAINER from www.dwhd.org by lookback (mondeolove@gmail.com)

ARG OC_VERSION=${OC_VERSION:-0.11.5}
ARG GLIBC_VERSION=${GLIBC_VERSION:-2.23-r3}
ENV INSTALL_DIR=/usr/local/ocserv \
	CONF_DIR=/etc/ocserv \
	TEMP_DIR=/tmp/ocserv

RUN set -x && \
	mkdir -p ${INSTALL_DIR} ${TEMP_DIR} ${CONF_DIR} && \
	cd ${TEMP_DIR} && \
# Get latest release
	LATEST_VERSION=$(curl -Lks http://www.infradead.org/ocserv/download.html|awk -F'>' '/latest released/{print $NF}') && \
# Install package
	apk --update --no-cache upgrade && \
	apk --update --no-cache add gnutls gnutls-utils iptables libev libintl libnl3 libseccomp linux-pam lz4 openssl readline sed && \
	apk --update --no-cache add --virtual .build-deps curl g++ gnutls-dev gpgme libev-dev libnl3-dev libseccomp-dev linux-headers linux-pam-dev lz4-dev make readline-dev tar xz && \
# Install glibc
	#for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION} glibc-i18n-${GLIBC_VERSION}; do \
	#	curl -Lk https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk;\
	#done && \
	#apk add --allow-untrusted /tmp/*.apk && \
# Install ocserv
	curl -Lk "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" | tar xJ -C ${TEMP_DIR} --strip-components=1 && \
	./configure --disable-seccomp && \
	make -j$(getconf _NPROCESSORS_ONLN) && \
	make install && \
	cp doc/sample.config /etc/ocserv/ocserv.conf && \
# Setup config
	sed -i 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' /etc/ocserv/ocserv.conf && \
	sed -i 's/\(max-same-clients = \)2/\110/' /etc/ocserv/ocserv.conf && \
	sed -i 's/\.\.\/tests/\/etc\/ocserv/' /etc/ocserv/ocserv.conf && \
	sed -i 's/#\(compression.*\)/\1/' /etc/ocserv/ocserv.conf && \
	sed -i '/^ipv4-network = /{s/192.168.1.0/192.168.99.0/}' /etc/ocserv/ocserv.conf && \
	sed -i 's/192.168.1.2/8.8.8.8/' /etc/ocserv/ocserv.conf && \
	sed -i 's/^route/#route/' /etc/ocserv/ocserv.conf && \
	sed -i 's/^no-route/#no-route/' /etc/ocserv/ocserv.conf && \
	mkdir -p /etc/ocserv/config-per-group && \
	echo -e "default-select-group = Route[仅海外代理 Exclude CN]\nselect-group = All[全局代理 All Proxy]\nauto-select-group = false\nconfig-per-group = /etc/ocserv/config-per-group" >> /etc/ocserv/ocserv.conf && \
# Clean system
	rm -fr /tmp/cn-no-route.txt && \
	rm -fr ${TEMP_DIR} && \
	apk del .build-deps && \
	rm -rf /var/cache/apk/* /tmp/*.apk

WORKDIR /etc/ocserv

COPY All /etc/ocserv/config-per-group/All
COPY cn-no-route.txt /etc/ocserv/config-per-group/Route

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
