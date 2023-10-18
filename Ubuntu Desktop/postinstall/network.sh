#!/bin/bash

POSITIONAL_ARGS=()

helpFunction()
{
	echo ""
	echo "Usage: $0 --ip-address ... --ip-mask ... --ip-gateway ... --ip-dns ..."
	echo -e "\t--ip-address\tIP address of this machine."
	echo -e "\t--ip-mask\tMask of subnet in digital notation from 1 to 32 (by default 24)."
	echo -e "\t--ip-gateway\tIP address of Gateway."
	echo -e "\t--ip-dns\tIP of DNS server (by default 8.8.8.8)."
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
		--help )
			helpFunction ; exit 1 ;;
		--* )
			echo "Unknown option $1."; exit 1 ;;
		* )
			POSITIONAL_ARGS+=("$1"); shift ;;
	esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ -z "$ipAddress" ] || [ -z "$ipGateway" ]
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

	read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] ]] || exit 1
  
	ethernet_iface="$(ls /sys/class/net | grep en)"
	printf "network:\n  version: 2\n  renderer: NetworkManager\n  ethernets:\n    %s:\n      wakeonlan: true\n      dhcp4: no\n      addresses: [%s/%s]\n      gateway4: %s\n      nameservers:\n        addresses: [%s]\n" $ethernet_iface $ipAddress $ipMask $ipGateway $ipDNS > /etc/netplan/nttek-netplan.yaml
	netplan apply
 	sleep 2
	ethernet_mac="$(ip link show | awk '/link\/ether/ {print $2}')"
	printf "network:\n  version: 2\n  renderer: NetworkManager\n  ethernets:\n    %s:\n      match:\n        macaddress: %s\n      wakeonlan: true\n      dhcp4: no\n      addresses: [%s/%s]\n      gateway4: %s\n      nameservers:\n        addresses: [%s]\n" $ethernet_iface $ethernet_mac $ipAddress $ipMask $ipGateway $ipDNS > /etc/netplan/nttek-netplan.yaml
 	netplan apply

	apt -y --force-yes install sssd sssd-ldap ldap-utils openssh-server

  echo -e "Now run sssd.sh file."
fi
