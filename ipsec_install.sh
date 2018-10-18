#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
 
DOWNLOAD_VERSION=5.5.3
#===============================================================================================
#   System Required:  CentOS6.x (32bit/64bit)
#   Description:  Install IKEV2 VPN for CentOS
#===============================================================================================
 
clear
echo "#############################################################"
echo "# Install StrongSWan IKEV2 VPN for CentOS6.x (32bit/64bit)"
echo "#############################################################"
echo ""
 
# Install IKEV2
function install_ikev2(){
 rootness
 disable_selinux
 yum_install
 pre_install
 download_files
 setup_strongswan
 configure_ipsec
 configure_strongswan
 configure_secrets
 iptables_set
 sysctl_set
 success_info
    
}
 
# Make sure only root can run our script
function rootness(){
if [[ $EUID -ne 0 ]]; then
   echo "Error:This script must be run as root!" 1>&2
   exit 1
fi
}
 
# Disable selinux
function disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
}
 

# Pre-installation settings
function pre_install(){
    cur_dir=`pwd`
    cd $cur_dir
}
 
#install necessary lib
function yum_install(){
    yum -y install pam-devel openssl-devel make gcc gmp-devel
}
 
# Download strongswan
function download_files(){
    if [ -f strongswan-$DOWNLOAD_VERSION.tar.gz ];then
        echo -e "strongswan-$DOWNLOAD_VERSION.tar.gz [\033[32;1mfound\033[0m]"
    else
        if ! wget https://download.strongswan.org/strongswan-$DOWNLOAD_VERSION.tar.gz;then
            echo "Failed to download strongswan.tar.gz"
            exit 1
        fi
    fi
    tar xzf strongswan-$DOWNLOAD_VERSION.tar.gz
    if [ $? -eq 0 ];then
        cd $cur_dir/strongswan-$DOWNLOAD_VERSION/
    else
        echo ""
        echo "Unzip strongswan.tar.gz failed!"
        exit 1
    fi
}
 
# configure and install strongswan
function setup_strongswan(){
./configure --prefix=/usr --sysconfdir=/etc  --enable-openssl --enable-nat-transport --disable-mysql --disable-ldap  \
--disable-static --enable-shared --enable-md4 --enable-eap-mschapv2 --enable-eap-aka --enable-eap-aka-3gpp2  --enable-eap-gtc \
--enable-eap-identity --enable-eap-md5 --enable-eap-peap --enable-eap-radius --enable-eap-sim --enable-eap-sim-file \
--enable-eap-simaka-pseudonym --enable-eap-simaka-reauth --enable-eap-simaka-sql --enable-eap-tls --enable-eap-tnc --enable-eap-ttls 
make
make install
}
 

# configure the ipsec.conf
function configure_ipsec(){
cat > /etc/ipsec.conf<<-EOF
config setup
    uniqueids=never 
 
conn %default  
     left=%any
     rekey=no  
     leftsubnet=0.0.0.0/0  
     right=%any    
     rightsubnet=10.11.0.0/24
     rightsourceip=10.11.0.0/24  
     dpdaction=clear
     fragmentation=yes
conn ikev2_psk_eap_ios
    keyexchange=ikev2
    rekey=no
    leftid=vpn
    left=%any
    leftauth=psk
    right=%any
    rightauth=eap-mschapv2
    eap_identity=%any
    auto=add
conn ikev1_xauth_psk_ipsec
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    right=%any
    rightauth=psk
    rightauth2=xauth
    auto=add

EOF
}
 
# configure the strongswan.conf
function configure_strongswan(){
 cat > /etc/strongswan.conf<<-EOF
 charon {
        i_dont_care_about_security_and_use_aggressive_mode_psk = yes
        install_virtual_ip = yes
        load_modular = yes
        duplicheck.enable = no
        compress = yes
        plugins {
                include strongswan.d/charon/*.conf
        }
        dns1 = 8.8.8.8
        dns2 = 8.8.4.4
}
include strongswan.d/*.conf
EOF
}
 
# configure the ipsec.secrets
function configure_secrets(){
 cat > /etc/ipsec.secrets<<-EOF
: PSK "123456"
: XAUTH "123456"
vpnuser : EAP "lin12345"
EOF
}
# sysctl set
function sysctl_set(){
    cat > /etc/sysctl.conf<<-EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.neigh.default.gc_stale_time=120
net.ipv4.tcp_max_tw_buckets = 1000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096        87380   4194304
net.ipv4.tcp_wmem = 4096        16384   4194304
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 15
net.ipv4.ip_local_port_range = 1024    65000
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 262144
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
fs.file-max = 6554428
fs.nr_open = 1048576
EOF
    
    sysctl -p
}
 
# iptables set
function iptables_set(){
    cat > /etc/sysconfig/iptables<<-EOF
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A POSTROUTING -s 10.11.0.0/24 -j MASQUERADE
COMMIT

*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
-A INPUT -p udp -m udp --sport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p esp -j ACCEPT
-A INPUT -p udp -m udp --dport 500 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 500 -j ACCEPT
-A INPUT -p udp -m udp --dport 4500 -j ACCEPT
-A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 10.11.0.0/24 -j ACCEPT
COMMIT
EOF
    
    service iptables restart
}
 
# echo the success info
function success_info(){
 echo "#############################################################"
 echo -e "#"
 echo -e "# [\033[32;1mInstall Successful\033[0m]"
 echo -e "# There is the default login info of your VPN"
 echo -e "# UserName:\033[33;1m vpnuser\033[0m"
 echo -e "# PassWord:\033[33;1m lin12345\033[0m"
 echo -e "# PSK:\033[33;1m 123456\033[0m"
        echo -e "# XAUTH:\033[33;1m 123456\033[0m"
 echo -e "# you can change UserName and PassWord in:\033[32;1m /etc/ipsec.secrets\033[0m"
 echo -e "# you can startup VPN server with debug:\033[32;1m ipsec start --nofork\033[0m"
 echo -e "#############################################################"
 echo -e ""
}
 
# Initialization step
install_ikev2