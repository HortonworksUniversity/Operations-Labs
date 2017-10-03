#!/usr/bin/env bash

sudo yum -y -q install git
sudo git clone https://github.com/HortonworksUniversity/Ops_Labs/1.1.0/build/security/ambari-bootstrap /opt/ambari-bootstrap
sudo chmod -R g+rw /opt/ambari-bootstrap
sudo chown -R ${USER}:users /opt/ambari-bootstrap
ln -s /opt/ambari-bootstrap ~/

