#!/bin/bash

usage()
{
	echo "usage:  -d  Debug"
	echo "        -h   Help"
}

while [ "$1" != "" ]; do
	case $1 in
		-h )
			usage
			exit
			;;
		-d )
			set -x
			;;
		* )
			usage
			exit 1
	esac
	shift
done

# Check to make sure the user is running as root
if [[ $EUID -ne 0 ]]; then
	echo "You must run this as root"
	exit 1
fi

# Disable SELinux
setenforce Permissive

# Copy Centos Disk to PXE server
echo "Please mount the Centos install disk to /mnt and pres RETURN"
read USERINPUT

# Check to make sure the disk is mounted
DISKMOUNT=$(ls -l /mnt/ | grep CentOS_BuildTag | wc -l)
if [ $DISKMOUNT == 0; then
	#Not Found
	echo "Centos install disk not found....exiting!"
	exit 1
fi

#Copy the install disk
mkdir -p /srv/centos/7
cp -r /mnt/* /srv/centos/7/
chmod -R 755 /srv/centos/*

# Use temporary repo
rm -f /etc/yum.repos.d/Cent*
cat << EOM > /stc/yum.repos.d/local.repo
[base[
name=master - Base
baseurl=file:///srv/centos/7
gpgcheck=0
enabled=1
EOM

#Update Repo
yum clean all
yum update -y

rm -f /etc/yum.repos.d/Cent*

#Install packages
yum install -y ipa-cllient
yum install -y tftp-server
yum install -y syslinkux
yum install -y dhcp
yum install -y httpd
yum install -y git

#Configure Firewall
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --permanent --add-port=69/udp
firewall-cmd --permanent --add-port=69/tcp
firewall-cmd --reload

sed -i '/disable/c\\tdisable \t\t= no' /etc/xinetd.d/tftp

#Copy boot loader
mkdir -p /tftpboot
mkdir -p tftpboot/images
ln -s /srv/centos /tftp/images
cp /usr/share/syslinux/pxelinux.0 /tftpboot/
cp /usr/share/syslinux/menu.c32 /tftpboot/
cp /usr/share/syslinux/memdisk /tftpboot/
cp /usr/share/syslinux/mboot.c32 /tftpboot/
cp /usr/share/syslinux/chain.c32 /tftpboot/

mkdir -p /var/www/html/ks/
mkdir -p /var/www/html/images/
ln -s /srv/centos/ /var/www/html/images/
chmod 755 /tftpboot/*

#Configure DHCP
cat << EOM > /etc/dhcp/dhcpd.conf
option domain-name "warroom.kit";
option domain-name-servers 172.16.3.23;
default-lease-time 600;
max-lease-time 600;
subnet 172.16.3.0 netmask 255.255.255.0 {
	range dynamic-bootp 172.16.3.200 172.16.3.254;
	option broadcast-address 172.16.3.255;
	option routers 172.16.3.1;
	next-server 172.16.3.2;
	filename "pxelinux.0";
}
EOM

systemctl enable tftp
systemctl start tftp
systemctyl enable httpd
systemctl start httpd
systemctl enable dhcpd
systemctl start dhcpd

#Modify logrotate
sed -i '/#compress/c\compress' /etc/logrotate.conf
sed -i '/rotate /c\rotate 2' /etc/logrotate.conf

echo "Setup Complete!"
echo "Please Complete the following tasks:
echo ""
echo "1.  Bring in the kickstart git and run the setup"
echo "2.  Bring up the Centos repo server and get a full update in place"
echo "3.  Run 'yum clean all && yum update -y'"
echo "4.  Once the IPA server is operational, add this server to the domain"
