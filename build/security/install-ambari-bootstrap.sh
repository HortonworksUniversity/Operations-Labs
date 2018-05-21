#!/usr/bin/env bash

#sudo yum -y -q install git
#sudo git clone https://github.com/HortonworksUniversity/Ops_Labs/1.1.0/build/security/ambari-bootstrap /opt/ambari-bootstrap
#sudo chmod -R g+rw /opt/ambari-bootstrap
#sudo chown -R ${USER}:users /opt/ambari-bootstrap
#ln -s /opt/ambari-bootstrap ~/

sudo yum update -y -q curl
sudo yum update -y -q --exclude=mysql-community-release-el7-5 
sudo yum -y -q install git

sudo git clone -b 1.1.0 https://github.com/HortonworksUniversity/Ops_Labs /opt/ambari-bootstrap
cd /opt/ambari-bootstrap
sudo git filter-branch --prune-empty --subdirectory-filter build/security/ambari-bootstrap-master

sudo chmod -R g+rw /opt/ambari-bootstrap
sudo chown -R ${USER}:users /opt/ambari-bootstrap
ln -s /opt/ambari-bootstrap ~/
