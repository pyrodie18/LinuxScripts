#!/bin/bash -x
#  This is an automated BASH script to build an IPA server from a clean Centos 7.0 install.  It requires access to a functioning repo server.
#  Written By:  Troy Ward
#  Updated 2/21/18
#  Version 1.0.1
#
# Change Log:
#
# 1.0.1  2/26/18
#       Added additional commands to sudo groups
#       Basic formatting updates


ChangeIP () {
    #Function to change the IP address of the box
    FILES=$(ls /etc/sysconfig/network-scripts/ | grep ifcfg | grep -v lo)

    echo "Please enter the primary network interface from this list"
    echo $FILES
    echo ""
    read FILE

    #Check to make sure the file exists
    if [ ! -f /etc/sysconfig/network-scripts/"$FILE" ]; then
    echo "You did not enter a valid file name.  Exiting program"
    exit 2
    fi

    #Get ip address info
    echo "What IP address would you like to configure?"
    read IPADDR
    echo "What is the subnet mask?"
    read NETMASK
    echo "What is the default gateway?"
    read GATEWAY

    #SET IP ADDRESS
    sed -i '/BOOTPROTO/c\BOOTPROTO="static"' /etc/sysconfig/network-scripts/$FILE
    sed -i '/ONBOOT/c\ONBOOT="yes"' /etc/sysconfig/network-scripts/$FILE

    echo "Setting IP Address to $IPADDR"
    if [ $(grep GATEWAY /etc/sysconfig/network-scripts/$FILE | wc -l) == 1 ]; then
        sed -i "/GATEWAY/c\GATEWAY=$GATEWAY" /etc/sysconfig/network-scripts/$FILE
    else
        echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network-scripts/$FILE
    fi

    echo "Setting gateway to $GATEWAY"
    if [ $(grep IPADDR /etc/sysconfig/network-scripts/$FILE | wc -l) == 1 ]; then
        sed -i "/IPADDR/c\IPADDR=$IPADDR" /etc/sysconfig/network-scripts/$FILE
    else
        echo "IPADDR=$IPADDR" >> /etc/sysconfig/network-scripts/$FILE
    fi

    echo "Setting netmask to $NETMASK"
    if [ $(grep NETMASK /etc/sysconfig/network-scripts/$FILE | wc -l) == 1 ]; then
        sed -i "/NETMASK/c\NETMASK=$NETMASK" /etc/sysconfig/network-scripts/$FILE
    else
        echo "NETMASK=$MASK" >> /etc/sysconfig/network-scripts/$FILE
    fi
    if [ $(grep DNS1 /etc/sysconfig/network-scripts/$FILE | wc -l) == 1 ]; then
        sed -i '/DNS1/c\DNS1="192.168.122.1"' /etc/sysconfig/network-scripts/$FILE
        #sed -i '/DNS1/c\DNS1="$IPADDR"' /etc/sysconfig/network-scripts/$FILE
    else
        echo "DNS1=$IPADDR" >> /etc/sysconfig/network-scripts/$FILE
        #echo "DNS1=192.168.122.1" >> /etc/sysconfig/network-scripts/$FILE
    fi

    #RESTART NETWORKING SERVICES
    echo "Restarting Networking Services"
    #systemctl restart network
}

#update repos
yum update -y
yum install -y vim net-tools ipa-server bind-dyndp-ldap ipa-server-dns rng-tools

#Check IP Config
FILES=$(ls /etc/sysconfig/network-scripts/ | grep ifcfg | grep -v lo)
ADDRSET="FALSE"
for FILE in $FILES; do
    if [ $(grep static /etc/sysconfig/network-scripts/$FILE | wc -l) == 1 ]; then
    
        #STATIC CONFIG FOUND, PULL OUT THE INFO AND SEE IF ITS CORRECT
        n='[0-9]\{1,3\}'
        IPADDR=$(cat /etc/sysconfig/network-scripts/$FILES | sed 's/\"//g' |grep IPADDR | sed "s/.*\=\($n\.$n\.$n\.$n\).*/\1/")
        NETMASK=$(cat /etc/sysconfig/network-scripts/$FILES | sed 's/\"//g' |grep NETMASK | sed "s/.*\=\($n\.$n\.$n\.$n\).*/\1/")
        GATEWAY=$(cat /etc/sysconfig/network-scripts/$FILES | sed 's/\"//g' |grep GATEWAY | sed "s/.*\=\($n\.$n\.$n\.$n\).*/\1/")
        DNS=$(cat /etc/sysconfig/network-scripts/$FILES | sed 's/\"//g' |grep DNS1 | sed "s/.*\=\($n\.$n\.$n\.$n\).*/\1/")

        echo "Interface $FILE currently has the following configuration"
        echo "IP Address:  $IPADDR"
        echo "Subnet Mask:  $NETMASK"
        echo "Gateway:  $GATEWAY"
        echo "DNS:  $DNS"
        echo
        echo "Is this correct?"
        read USERINPUT

        if [[ $USERINPUT == "y"* ]] || [[ $USERINPUT == "Y"* ]]; then
            ADDRSET="TRUE"
        fi
    fi
done

if [ $ADDRSET == "FALSE" ]; then
    echo "This VM does not currently have a static IP address configured"
    ChangeIP
fi

#CONFIGURE HOSTNAME
echo "Please enter your domain [warroom2.kit]"
read USERINPUT
if [ -z $USERINPUT ]; then
    DOMAIN="warroom2.kit"
else
    DOMAIN=$USERINPUT
fi

echo "Please enter your computer name without domain [auth]:"
read USERINPUT
if [ -z $USERINPUT ]; then
    COMPUTERNAME="auth"
else
    COMPUTERNAME=$USERINPUT
fi

DOMAINNAME="$COMPUTERNAME.$DOMAIN"
echo $DOMAINNAME
hostname $DOMAINNAME
echo "$DOMAINNAME" > /etc/hostname
echo $IPADDR
echo "$IPADDR      $DOMAINNAME" >> /etc/hosts

systemctl restart network

#CONFIGURE FIREWALL
firewall-cmd --permanent --zone=public --add-service={ntp,http,https,ldap,ldaps,kerberos,kpasswd,dns}
firewall-cmd --reload

#GENERATING RANDOMNESS FOR IPA CERTS
echo "Generating Randomness for IPA certs....This will take a min."
cat /dev/urandom | rngtest -c 500

# GENERATE ADMIN PASSWORDS AND INSTALL IPA SERVER
DMPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#%^&' | fold -w 15 | head -n 1)
ADMINPASSWORD==$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#%^&' | fold -w 15 | head -n 1)
REALM=$(echo $DOMAIN | tr a-z A-Z)
ipa-server-install --real=$REALM --domain=$DOMAIN --ds-password=$DMPASSWORD --admin-password=$ADMINPASSWORD --hostname=$DOMAINNAME --ip-address=$IPADDR --setup-dns --no-forwarders --mkhomedir --auto-reverse -U

#INTIALIZE ADMIN ACCOUNT
echo $ADMINPASSWORD | kinit admin

#Add User groups
ipa group-add INF-Admin --desc "Infastructure Admins"
ipa group-add INF-PU --desc "Infastructure Power Users"
ipa group-add Splunk-User --desc "Splunk User"
ipa group-add Splunk-PU --desc "Splunk Power User"
ipa group-add Splunk-Admin --desc "Splunk Admin"
ipa group-add Sensor-Admin --desc "Sensor Admin"
ipa group-add NET-Analyst --desc "Network Analyst"
ipa group-add Analyst --desc "Standard Analyst"

#Add Host groups
ipa hostgroup-add INF --desc "Infastructure Server"
ipa hostgroup-add INF-IPA --desc "Infastructure IPA Servers"
ipa hostgroup-add INF-Physical --desc "Physical Infastructure Server"
ipa hostgroup-add INF-Virtual --desc "Virtual Infastructure Server"
ipa hostgroup-add Splunk --desc "Splunk Server"
ipa hostgroup-add NET-Sensor --desc "Network Sensor"
ipa hostgroup-add ANL-Workstation --desc "Analyst Workstation"
ipa hostgroup-add-member INF-IPA --hostgroups=INF
ipa hostgroup-add-member INF-Physical --hostgroups=INF
ipa hostgroup-add-member INF-Virtual --hostgroups=INF

#Update Password Policy
ipa pwpolicy-mod --history=10 --minclasses=4 --minlength=12 --maxfail=6 --failinterval=60 --lockouttime=300

#Add sudo commands
ipa sudocmd-add /usr/bin/less --desc="For reading log files"
ipa sudocmd-add /usr/bin/more --desc="For reading log files"
ipa sudocmd-add /usr/bin/cat --desc="For reading log files"
ipa sudocmd-add /usr/bin/vim --desc="For editing files"
ipa sudocmd-add /usr/bin/vi --desc="For editing files"
ipa sudocmd-add /usr/bin/awk --desc="For editing files"
ipa sudocmd-add /usr/bin/systemctl --desc="For starting/stoping services"
ipa sudocmd-add /usr/sbin/service --desc="For starting/stopping services"
ipa sudocmd-add /usr/sbin/shutdown --desc="Shutdown a system"
ipa sudocmd-add /usr/sbin/reboot --desc="Reboot a system"
ipa sudocmd-add /usr/sbin/ifconfig --desc="Configure IP Address"
#TCPdump
#Bro
#Surricata
#Snort
#netsniff
#nmap


#Add sudo groups
ipa sudocmdgroup-add sgrp-view-files --desc="View files commands"
ipa sudocmdgroup-add sgrp-edit-files --desc="Edit file commands"
ipa sudocmdgroup-add sgrp-system-restart --desc="System restart commands"
ipa sudocmdgroup-add sgrp-services --desc="Commands to manage services"
ipa sudocmdgroup-add sgrp-IDS --desc="IDS commands"
ipa sudocmdgroup-add sgrp-packet-capture --desc="Packet Capture"
ipa sudocmdgroup-add sgrp-enumeration --desc="Enumeration Tools"

#Put sudo commands in groups
ipa sudocmdgroup-add-member sgrp-view-files --sudocmds "/usr/bin/less"
ipa sudocmdgroup-add-member sgrp-view-files --sudocmds "/usr/bin/more"
ipa sudocmdgroup-add-member sgrp-view-files --sudocmds "/usr/bin/cat"
ipa sudocmdgroup-add-member sgrp-edit-files --sudocmds "/usr/bin/vim"
ipa sudocmdgroup-add-member sgrp-edit-files --sudocmds "/usr/bin/vi"
ipa sudocmdgroup-add-member sgrp-edit-files --sudocmds "/usr/bin/awk"
ipa sudocmdgroup-add-member sgrp-system-restart --sudocmds "/usr/sbin/shutdown"
ipa sudocmdgroup-add-member sgrp-system-restart --sudocmds "/usr/sbin/restart"
ipa sudocmdgroup-add-member sgrp-services --sudocmds "/usr/bin/systemctl"
ipa sudocmdgroup-add-member sgrp-services --sudocmds "/usr/bin/service"

#Add sudo rules
#Configure srule-analyst-laptop
ipa sudorule-add srule-analyst-laptop --desc="Standard Analyst rules on analyst laptops (limited sudo)"
ipa sudorule-add-allow-command srule-analyst-laptop --sudocmds=/usr/sbin/ifconfig --sudocmdgroups=sgrp-view-files --sudocmdgroups=sgrp-system-restart --sudocmdgroups=sgrp-services
ipa sudorule-add-host srule-analyst-laptop --hostgroups=ANL-Workstation
ipa sudorule-add-user srule-analyst-laptop --groups=Analyst
ipa sudorule-add-runasuser srule-analyst-laptop --users=root

#Configure srule-admin-sensor
ipa sudorule-add srule-admin-sensor --desc="Sensor admin rules on sensors (allow all)" --cmdcat='all'
ipa sudorule-add-host srule-admin-sensor --hostgroups=NET-Sensor
ipa sudorule-add-user srule-admin-sensor --groups=Sensor-Admin
ipa sudorule-add-runasuser srule-admin-sensor --users=root

#Configure srule-admin-inf
ipa sudorule-add srule-admin-inf --desc="Infastructure admin rules on all devices (allow all)" --cmdcat='all' --hostcat='all'
ipa sudorule-add-user srule-admin-inf --groups=INF-Admin
ipa sudorule-add-runasuser srule-admin-inf --users=root

#Configure srule-admin-splunk
ipa sudorule-add srule-admin-splunk --desc="Splunk admin rules on splunk machines (allow all)" --cmdcat='all'
ipa sudorule-add-host srule-admin-splunk --hostgroups=Splunk
ipa sudorule-add-user srule-admin-splunk --groups=Splunk-Admin
ipa sudorule-add-runasuser srule-admin-splunk --users=root

#OUTPUT PASSWORDS
echo "Do not loose these passwords!!!!!"
echo "Admin password:  $ADMINPASSWORD"
echo "DS password:  $DMPASSWORD"
