#!/usr/bin/env bash
set -o xtrace

export HOME=${HOME:-/root}
export TERM=xterm
export ambari_pass=${ambari_pass:-BadPass#1}
#export ambari_server_custom_script=${ambari_server_custom_script:-~/ambari-bootstrap/ambari-extras.sh}

cd

cp -a /etc/yum.repos.d/CentOS-Base.repo /root/CentOS-Base.repo.bak
curl -sSL https://raw.githubusercontent.com/HortonworksUniversity/Operations-Labs/master/build/security/CentOS-Base.repo.7.4.1708 > /etc/yum.repos.d/CentOS-Base.repo
yum clean all
yum makecache
yum -y -q install vim git epel-release ntp screen mysql-connector-java jq python-configobj pip
sudo pip install --upgrade pip
pip install argparse oauth pyserial
