#!/bin/bash

CA_CN=${CA_CN:-"dwhd"}
CA_ORG=${CA_ORG:-"OPS"}
CA_DAYS=${CA_DAYS:-3650}
SRV_CN=${SRV_CN:-"www.dwhd.org"}
SRV_ORG=${SRV_ORG:-Legion}
SRV_DAYS=${SRV_DAYS:-36500}

ADD_ROUTE_GROUP=${ADD_ROUTE_GROUP:-disable}
ADD_ROUTE_GROUP_FILE=${ADD_ROUTE_GROUP_FILE:-/tmp/ocserv_group}
ADD_ROUTE_GROUP_NAME=${ADD_ROUTE_GROUP_NAME:-DS}

if [[ "${ADD_ROUTE_GROUP}" =~ [eE][nN][aA][bB][lL][eE] ]]; then
	if [[ "${#ADD_ROUTE_GROUP_NAME[@]}" == "1" ]]; then
		sed -i "/^select-group/a select-group = ${ADD_ROUTE_GROUP_NAME}[Custom Group : ${ADD_ROUTE_GROUP_NAME}]" /etc/ocserv/ocserv.conf
		cat ${ADD_ROUTE_GROUP_FILE} > /etc/ocserv/config-per-group/"${ADD_ROUTE_GROUP_NAME}"
	elif [[ "${#ADD_ROUTE_GROUP_NAME[@]}" > "1" ]]; then
		if [[ "${#ADD_ROUTE_GROUP_NAME[@]}" == "${#ADD_ROUTE_GROUP_FILE[@]}" ]]; then
			for i in `seq 0 $(expr ${#ADD_ROUTE_GROUP_NAME[@]} - 1)`;do
				echo "select-group = ${ADD_ROUTE_GROUP_NAME[$i]}[Custom Group : ${ADD_ROUTE_GROUP_NAME[$i]}]" >> /etc/ocserv/ocserv.conf
				cat ${ADD_ROUTE_GROUP_FILE[$i]} > /etc/ocserv/config-per-group/"${ADD_ROUTE_GROUP_NAME[$i]}"
			done
		else
			echo >&2 -e "\033[41;37;1mThe array subscripts for ADD_ROUTE_GROUP_NAME and ADD_ROUTE_GROUP_FILE do not match.\033[39;49;0m"
			exit 1
		fi
	fi
fi

if [ ! -f /etc/ocserv/certs/server-key.pem ] || [ ! -f /etc/ocserv/certs/server-cert.pem ]; then
	# No certification found, generate one
	mkdir /etc/ocserv/certs
	cd /etc/ocserv/certs
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
	sleep 2 && if [[ "$TEST_USER" =~ [dD][iI][sS][aA][bB][lL][eE] ]] && [ ! -f /etc/ocserv/ocpasswd ]; then
		echo "Create test user 'test' with password 'test'"
		echo 'test:Route,All:$5$DktJBFKobxCFd7wN$sn.bVw8ytyAaNamO.CvgBvkzDiFR6DaHdUzcif52KK7' > /etc/ocserv/ocpasswd
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
exec "$@"
