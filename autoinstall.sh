#!/bin/bash -ex

################################################################################
# flexiWAN SD-WAN software - flexiEdge, flexiManage.
# For more information go to https://flexiwan.com
#
# Copyright (C) 2020  flexiWAN Ltd.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
################################################################################

################################################################################
# Use 'sh auto-install.sh'
# By executing this shell script it will install the required packages into the TEC machine from where we can start
# the automated regression
################################################################################

PACKAGES="build-essential net-tools zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev
          libsqlite3-dev wget libbz2-dev unzip xvfb libxi6 libgconf-2-4 software-properties-common python3 python3-pip python3-venv
	  python3-webcolors qemu mkisofs"

# check_and_install_packer_and_terraform(){
#         echo "Installing Packer and Terraform from Hashicorp repo"
#         curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
#         sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
#         sudo apt-get update && sudo apt-get install -y packer=1.8.7-1 terraform=1.4.6-1
#         echo "Packer and Terraform Successfully Installed"
# }

env 
echo "Proceeding with the Installation... Following packages will be installed"
echo
echo $PACKAGES
echo
sudo apt update -y
sudo apt-get install -y $PACKAGES
sudo python3 -m pip install --upgrade pip
sudo -H pip3 install wheel 
sudo -H pip3 install setuptools==60.2.0 
sudo -H pip3 install setuptools-rust==1.3.0
sudo python3 -m pip install -r requirements.txt


#Function call to Install Packer and Terraform
# check_and_install_packer_and_terraform
# echo
# echo "Packages are Successfully installed"
# echo
