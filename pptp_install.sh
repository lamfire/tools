#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS6.x (32bit/64bit)
#   Description:  Install PPTP VPN for CentOS
#===============================================================================================
 
clear
echo "#############################################################"
echo "# Install PPTP VPN for CentOS6.x (32bit/64bit)"
echo "#############################################################"
echo ""
 
# Install
function startup_install(){
  rootness
  disable_selinux
  yum_install_libs
  pre_install
  download_files
  setup_pptpd
  configure_options_pptpd
  configure_options
  configure_pptpd_conf
  configure_chap_secrets
  iptables_set
  sysctl_set
  setup_autostartup
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
function yum_install_libs(){
    yum -y install perl ppp
}
 
# Download 
function download_files(){
    if [ -f pptpd-1.4.0-1.el6.x86_64.rpm ];then
        echo -e "pptpd-1.4.0-1.el6.x86_64.rpm [\033[32;1mfound\033[0m]"
    else
        if ! wget http://poptop.sourceforge.net/yum/stable/packages/pptpd-1.4.0-1.el6.x86_64.rpm;then
            echo "pptpd-1.4.0-1.el6.x86_64.rpm"
            exit 1
        fi
    fi
}
 
# configure and install strongswan
function setup_pptpd(){
   rpm -ivh pptpd-1.4.0-1.el6.x86_64.rpm
}
 
 
# configure the options.pptpd
function configure_options_pptpd(){
cat > /etc/ppp/options.pptpd<<-EOF
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
ms-dns 8.8.8.8
ms-dns 8.8.4.4
mtu 1400
mru 1400
 
EOF
}
 
# configure the options
function configure_options(){
cat > /etc/ppp/options<<-EOF
asyncmap 0
auth
crtscts
lock
hide-password
modem
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
noipx
EOF
}
 
# configure the pptpd.conf
function configure_pptpd_conf(){
 cat > /etc/pptpd.conf<<-EOF
option /etc/ppp/options.pptpd
logwtmp
localip 192.168.254.1
remoteip 192.168.254.100-254
EOF
}
 
# configure the chap-secrets
function configure_chap_secrets(){
cat > /etc/ppp/chap-secrets<<-EOF
vpnuser pptpd lin12345 *
EOF
}
 
# sysctl set
function sysctl_set(){
  sed -n 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/p' /etc/sysctl.conf
  sysctl -p
}
 
# iptables set
function iptables_set(){
  iptables -t nat -A POSTROUTING -s 192.168.254.0/24 -j MASQUERADE
  iptables -A INPUT -p UDP --dport 53 -j ACCEPT
  iptables -A INPUT -p tcp --dport 1723 -j ACCEPT
  iptables -A INPUT -p tcp --dport 47 -j ACCEPT
  iptables -A INPUT -p gre -j ACCEPT
  service iptables save
  service iptables restart
}
 
function setup_autostartup(){
  chkconfig pptpd on
  chkconfig iptables on
  service pptpd start
}
 
# echo the success info
function success_info(){
 echo "#############################################################"
 echo -e "#"
 echo -e "# [\033[32;1mInstall Successful\033[0m]"
 echo -e "# There is the default login info of your VPN"
 echo -e "# UserName:\033[33;1m vpnuser\033[0m"
 echo -e "# PassWord:\033[33;1m lin12345\033[0m"
 echo -e "# you can change UserName and PassWord in:\033[32;1m /etc/ppp/chap-secrets\033[0m"
 echo -e "#############################################################"
 echo -e ""
}
 
# Initialization step
startup_install