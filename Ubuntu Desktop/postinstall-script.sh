#!/bin/bash

POSITIONAL_ARGS=()

helpFunction()
{
    echo ""
    echo "Usage: $0 --ip-address ... --ip-mask ... --ip-gateway ... --ip-dns ... --ldap-cert ... --ldap-key ... --domain ... --ldap-base ..."
    echo -e "\t--ip-address\tIP address of this machine."
    echo -e "\t--ip-mask\tMask of subnet in digital notation from 1 to 32 (by default 16)."
    echo -e "\t--ip-gateway\tIP address of Gateway (by default 10.100.0.1)."
    echo -e "\t--ip-dns\tIP of DNS server (by default 10.100.1.101)."
    echo -e "\t--ldap-cert\tFull path to the certificate."
    echo -e "\t--ldap-key\tFull path to the private key."
    echo -e "\t--domain\tThe Domain name of the LDAP directory (e.g. example.com). Default: nttek.ru."
    echo -e "\t--ldap-base\tDomain name in the for of a DN record (e.g. dc=example,dc=com). Default: dc=nttek,dc=ru."
}

makeHeading()
{
    local input_string="$1"
    echo -e "\e[1;31m\n====================\n$input_string\n====================\n\e[0m"
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

if [ -z "$ipAddress" ] || [ -z "$keyPath" ] || [ -z "$certPath" ]
then
    echo "Some required parameters are empty!"
    helpFunction
    exit 1
else
    if [ -z "$ipMask" ]
    then
        ipMask="16"
    fi
    if [-z "$ipDNS" ]
    then
        ipDNS="10.100.1.101"
    fi
    if [ -z "$ipGateway" ]
    then
        idGateway="10.100.0.1"
    fi
    if [ -z "$domain" ]
    then
        domain="nttek.ru"
    fi
    if [-z "$dn"]
    then
        dn="dc=nttek,dc=ru"
    fi

    echo -e "Network settings:\n\tIP\t$ipAddress\n\tMask\t$ipMask\n\tGateway\t$ipGateway\n\tDNS\t$ipDNS\n"
    echo -e "LDAP settings:\n\tCertificate:\t$certPath\n\tPrivate key:\t$keyPath\n\tDomain:\t$domain\n\tDN:\t$dn"
    read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] ]] || exit 1

    echo "$(makeHeading 'Configure network settings...')"
    ethernet_iface="$(ls /sys/class/net | grep en)"
    
    printf "network:\n  version: 2\n  renderer: NetworkManager\n  ethernets:\n    %s:\n      dhcp4: no\n      addresses: [%s/%s]\n      routes:\n        - to: default\n          via: %s\n      nameservers:\n        addresses: [%s]\n" $ethernet_iface $ipAddress $ipMask $ipGateway $ipDNS > /etc/netplan/nttek-netplan.yaml
    netplan apply
    sleep 3

    ethernet_mac="$(ip link show | awk '/link\/ether/ {print $2}')"
    printf "network:\n  version: 2\n  renderer: NetworkManager\n  ethernets:\n    %s:\n      match:\n        macaddress: %s\n      wakeonlan: true\n      dhcp4: no\n      addresses: [%s/%s]\n      routes:\n        - to: default\n          via: %s\n      nameservers:\n        addresses: [%s]\n" $ethernet_iface $ethernet_mac $ipAddress $ipMask $ipGateway $ipAddress > /etc/netplan/nttek-netplan.yaml
    netplan apply
    sleep 2

    echo "$(makeHeading 'Configure SSSD settings...')"

    sssd_config="[sssd]\nservices = nss, pam, autofs\nconfig_file_version = 2\ndomains = $domain\n\n[domain/$domain]\nldap_tls_cert = /var/ldap/cert.crt\nldap_tls_key = /var/ldap/priv.key\nldap_tls_reqcert = never\nldap_uri = ldaps://ldap.google.com\nldap_search_base = $dn\nid_provider = ldap\nauth_provider = ldap\nldap_schema = rfc2307bis\nldap_user_uuid = entryUUID\nldap_groups_use_matching_rule_in_chain = false\nldap_initgroups_use_matching_rule_in_chain = false\ncreate_homedir = True\nauto_private_groups = true\nldap_referrals = false\n\n[pam]\noffline_credentials_expiration = 2\noffline_failed_login_attempts = 3\noffline_failed_login_delay = 5\ncache_credentials = true\nentry_cache_timeout = 604800\n"
    apt update
    apt install -y sssd sssd-ldap ldap-utils openssh-server
    mkdir /var/ldap
    cp $certPath /var/ldap/cert.crt
    cp $keyPath /vat/ldap/priv.key
    echo -e $sssd_config > /etc/sssd/sssd.conf
    chown -R root:root /var/ldap /etc/sssd/sssd.conf
    chmod -R 600 /var/ldap /etc/sssd/sssd.conf
    service sssd startstman (vi
    echo "$(makeHeading 'Configure autoload script...')"

    printf "#!/bin/bash\n\n### BEGIN INIT INFO\n# Provides:		nttek-setup.bash\n# Required-Start:	$sssd\n# Required-Stop:\n# Default-Start:	2 3 4 5\n# Default-Stop:		0 1 6\n# Short-Description:	This script provide some important fixes for Ubuntu Desktop.\n# Description:		This script will run after the sssd daemon starts.\n### END INIT INFO\n\nchgrp 1226889777 /var/run/docker.sock\n\nexit 0" > /etc/init.d/nttek-setup.bash
    chmod +x /etc/init.d/nttek-setup.bash
    update-rc.d nttek-setup.bash defaults

    echo "$(makeHeading 'Installing some applications...')"
    apt install -y software-properties-common apt-transport-https ca-certificates curl wget git mysql-client php-bcmath php-curl php-json php-mbstring php-mysql php-tokenizer php-xml php-zip php-cli sqlite3 php-sqlite3 unzip

    echo "$(makeHeading 'Installing GRUB Customizer...')"
    add-apt-repository -y ppa:danielrichter2007/grub-customizer
    apt update
    apt install -y grub-customizer

    echo "$(makeHeading 'Installing Google Chrome (stable)...')"
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    dpkg -i --force-depends google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb

    echo "$(makeHeading 'Installing Yandex Browser (stable)...')"
    curl --location 'https://browser.yandex.ru/download?banerid=6301000000&os=linux&package=deb&x64=1' --output Yandex.deb
    chmod +x Yandex.deb
    dpkg -i --force-depends Yandex.deb
    rm Yandex.deb
    add-apt-repository -y "deb https://repo.yandex.ru/yandex-browser/deb beta main"
    curl https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG --output YANDEX-BROWSER-KEY.GPG
    apt-key add YANDEX-BROWSER-KEY.GPG
    rm YANDEX-BROWSER-KEY.GPG

    echo "$(makeHeading 'Installing Visual Studio Code (stable)...')"
    wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
    add-apt-repository -y "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
    apt update
    apt install -y code

    echo "$(makeHeading 'Installing and configuring Docker...')"
    apt update
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    apt install -y docker-ce

    echo "$(makeHeading 'Installing InkScape (stable)...')"
    add-apt-repository -y ppa:inkscape.dev/stable
    apt update
    apt install -y inkscape

    echo "$(makeHeading 'Installing Oracle VM VirtualBox...')"
    apt install -y virtualbox

    echo "$(makeHeading 'Installing Postman (via SNAP)...')"
    snap install postman

    echo "$(makeHeading 'Now change password for user Administrator')"
    passwd administrator
fi
