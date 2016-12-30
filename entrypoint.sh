#!/bin/bash
#########################################################################
# File Name: entrypoint.sh
# Author: LookBack
# Email: admin#dwhd.org
# Version:
# Created Time: 2016年12月30日 星期五 01时00分20秒
#########################################################################

CA_CN=${CA_CN:-"dwhd"}
CA_ORG=${CA_ORG:-"OPS"}
CA_DAYS=${CA_DAYS:-3650}
SRV_CN=${SRV_CN:-"www.dwhd.org"}
SRV_ORG=${SRV_ORG:-Legion}
SRV_DAYS=${SRV_DAYS:-36500}

ADD_ROUTE_GROUP=${ADD_ROUTE_GROUP:-disable}
ADD_ROUTE_GROUP_FILE=${ADD_ROUTE_GROUP_FILE:-/tmp/ocserv_group}
ADD_ROUTE_GROUP_NAME=${ADD_ROUTE_GROUP_NAME:-DS}
OCSERV_CONF_DIR=${OCSERV_CONF_DIR:-/etc/ocserv}
OCSERV_GROUP_CONF=${OCSERV_GROUP_CONF:-"${OCSERV_CONF_DIR}/config-per-group"}

if [[ ! "${DEFAULTE_CONF}" =~ [dD][iI][sS][aA][bB][lL][eE] ]] && [[ "${ADD_ROUTE_GROUP}" =~ [eE][nN][aA][bB][lL][eE] ]]; then
	if [[ "${#ADD_ROUTE_GROUP_NAME[@]}" == "1" ]]; then
		sed -i "/^select-group/a select-group = ${ADD_ROUTE_GROUP_NAME}[Custom Group : ${ADD_ROUTE_GROUP_NAME}]" ${OCSERV_CONF_DIR}/ocserv.conf
		cat ${ADD_ROUTE_GROUP_FILE} > "${OCSERV_GROUP_CONF}/${ADD_ROUTE_GROUP_NAME}"
	elif [[ "${#ADD_ROUTE_GROUP_NAME[@]}" > "1" ]]; then
		if [[ "${#ADD_ROUTE_GROUP_NAME[@]}" == "${#ADD_ROUTE_GROUP_FILE[@]}" ]]; then
			for i in `seq 0 $(expr ${#ADD_ROUTE_GROUP_NAME[@]} - 1)`;do
				echo "select-group = ${ADD_ROUTE_GROUP_NAME[$i]}[Custom Group : ${ADD_ROUTE_GROUP_NAME[$i]}]" >> ${OCSERV_CONF_DIR}/ocserv.conf
				cat ${ADD_ROUTE_GROUP_FILE[$i]} > "${OCSERV_GROUP_CONF}/${ADD_ROUTE_GROUP_NAME[$i]}"
			done
		else
			echo >&2 -e "\033[41;37;1mThe array subscripts for ADD_ROUTE_GROUP_NAME and ADD_ROUTE_GROUP_FILE do not match.\033[39;49;0m"
			exit 1
		fi
	fi
fi


if [ ! -f ${OCSERV_CONF_DIR}/certs/server-key.pem ] || [ ! -f ${OCSERV_CONF_DIR}/certs/server-cert.pem ]; then
	# No certification found, generate one
	mkdir ${OCSERV_CONF_DIR}/certs
	cd ${OCSERV_CONF_DIR}/certs
	certtool --generate-privkey --outfile ca-key.pem
	cat > ca.tmpl <<-EOF
		cn = "$CA_CN"
		organization = "$CA_ORG"
		serial = 1
		expiration_days = $CA_DAYS
		ca
		signing_key
		cert_signing_key
		crl_signing_key
	EOF
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem
	certtool --generate-privkey --outfile server-key.pem
	cat > server.tmpl <<-EOF
		cn = "$SRV_CN"
		organization = "$SRV_ORG"
		expiration_days = $SRV_DAYS
		signing_key
		encryption_key
		tls_www_server
	EOF
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem

	# Create a test user
	sleep 2 && if [[ "$TEST_USER" =~ [dD][iI][sS][aA][bB][lL][eE] ]] && [ ! -f ${OCSERV_CONF_DIR}/ocpasswd ]; then
		echo "Create test user 'test' with password 'test'"
		echo 'test:Route,All:$6$6ywNf/mFnlMR7LYW$UhhHZuwE43OmphJLtDaDEGI/rk.723/eUUXQZ9XHbWrlRMSUlPHq4MHE9zcpL155OhSkFJDhivYkthrJrudXi1' > ${OCSERV_CONF_DIR}/ocpasswd
	fi
fi

# Open ipv4 ip forward
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
set -- "${@}" -c "${OCSERV_CONF_DIR}/ocserv.conf"
exec "$@"
