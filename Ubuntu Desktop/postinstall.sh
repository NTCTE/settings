#!/bin/bash

POSITIONAL_ARGS=()

helpFunction()
{
	echo ""
	echo "Usage: $0 --ip-address ... --ip-mask ... --ip-gateway ... --ip-dns ... --ldap-cert ... --ldap-key ... --domain ... --ldap-base ..."
	echo -e "\t--ip-address\tIP address of this machine."
	echo -e "\t--ip-mask\tMask of subnet in digital notation from 1 to 32 (by default 24)."
	echo -e "\t--ip-gateway\tIP address of Gateway."
	echo -e "\t--ip-dns\tIP of DNS server (by default 8.8.8.8)."
	echo -e "\t--ldap-cert\tFull path to the certificate."
	echo -e "\t--ldap-key\tFull path to the private key."
	echo -e "\t--domain\tThe Domain name of the LDAP directory (e.g. example.com)."
	echo -e "\t--ldap_base\tDomain name in the for of a DN record (e.g. dc=example,dc=com)."
}

while [[ $# -gt 0 ]]; do
	case $1 in
		--ip-address )
			ipAddress="$2"; shift; shift ;;
		--ip-mask )
			ipMask="$2"; shift; shift ;;
		--ip-gateway )
			ipGateway="$2"; shift; shift ;;
		--ip-dns )
			ipDNS="$2"; shift; shift ;;
		--ldap-key )
			keyPath="$2"; shift; shift ;;
		--ldap-cert )
			certPath="$2"; shift; shift ;;
		--domain )
			domain="$2"; shift; shift ;;
		--ldap-base )
			dn="$2"; shift; shift ;;
		--help )
			helpFunction ; exit 1 ;;
		--* )
			echo "Unknown option $1."; exit 1 ;;
		* )
			POSITIONAL_ARGS+=("$1"); shift ;;
	esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ -z "$ipAddress" ] || [ -z "$ipGateway" ] || [ -z "$keyPath" ] || [ -z "$certPath" ] || [ -z "$domain" ] || [ -z "$dn" ]
then
	echo "Some required parameters is empty!";
	helpFunction
else
	if [ -z "$ipMask" ]
	then
        	ipMask="24"
	fi
	if [ -z "$ipDNS" ]
	then
        	ipDNS="8.8.8.8"
	fi

	echo "Network settings:"
	echo -e "\tIP\t$ipAddress"
	echo -e "\tMask\t$ipMask"
	echo -e "\tGateway\t$ipGateway"
	echo -e "\tDNS\t$ipDNS"
	echo -e "LDAP settings:"
	echo -e "\tCertificate:\t$certPath"
	echo -e "\tPrivate key:\t$keyPath"
	echo -e "\tDomain:\t\t$domain"
	echo -e "\tDN:\t\t$dn"

	read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] ]] || exit 1

	sssd_config="[sssd]\nservices = nss, pam, autofs\nconfig_file_version = 2\ndomains = $domain\n\n[domain/$domain]\nldap_tls_cert = /var/ldap/cert.crt\nldap_tls_key = /var/ldap/priv.key\nldap_tls_reqcert = never\nldap_uri = ldaps://ldap.google.com\nldap_search_base = $dn\nid_provider = ldap\nauth_provider = ldap\nldap_schema = rfc2307bis\nldap_user_uuid = entryUUID\nldap_groups_use_matching_rule_in_chain = true\nldap_initgroups_use_matching_rule_in_chain = true\ncreate_homedir = True\nauto_private_groups = true\n\n[pam]\noffline_credentials_expiration = 2\noffline_failed_login_attempts = 3\noffline_failed_login_delay = 5\n"

	ethernet_iface="$(ls /sys/class/net | grep en)"
	# ethernet_mac="$(cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}')/address)"
	# \n      match:\n        macaddress: %s\n
	printf "network:\n  version: 2\n  renderer: NetworkManager\n  ethernets:\n    %s:      wakeonlan: true\n      dhcp4: no\n      addresses: [%s/%s]\n      gateway4: %s\n      nameservers:\n        addresses: [%s]\n" $ethernet_iface $ipAddress $ipMask $ipGateway $ipDNS > /etc/netplan/nttek-netplan.yaml
	netplan apply

	apt -y --force-yes install sssd sssd-ldap ldap-utils openssh-server
	mkdir /var/ldap
	cp $certPath /var/ldap/cert.crt
	cp $keyPath /var/ldap/priv.key
	echo -e $sssd_config > /etc/sssd/sssd.conf
	chown -R root:root /var/ldap /etc/sssd/sssd.conf
	chmod -R 600 /var/ldap /etc/sssd/sssd.conf
	service sssd start
	pam-auth-update --enable mkhomedir --enable sssdauth --enable sssd --updateall
	service sssd restart
	shutdown -r now
fi
