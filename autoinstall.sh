#!/bin/bash -ex

################################################################################
# Use 'bash auto-install.sh'
# By executing this shell script it will install the required packages into the TEC machine from where we can start
# the automated regression
################################################################################

PACKAGES="build-essential net-tools zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev
          libsqlite3-dev wget libbz2-dev unzip xvfb libxi6 libgconf-2-4 software-properties-common gnupg apt-transport-https ca-certificates 
          curl python3 python3-pip python3-venv python3-webcolors qemu mkisofs"

check_and_install_terraform(){
        echo "Installing Terraform from Hashicorp repo"
        sudo wget https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip
        sudo unzip terraform_1.12.2_linux_amd64.zip
        sudo mv terraform /usr/local/bin/
        sudo rm terraform_1.12.2_linux_amd64.zip
        terraform --version
        echo "Terraform Successfully Installed"
}
        
check_and_install_packer(){
        echo "Installing Packer from Hashicorp repo"
        sudo wget https://releases.hashicorp.com/packer/1.13.1/packer_1.13.1_linux_amd64.zip
        sudo unzip packer_1.13.1_linux_amd64.zip
        sudo mv packer /usr/local/bin/
        sudo rm packer_1.13.1_linux_amd64.zip
        packer --version
        echo "Packer Successfully Installed"
}

env 
echo "Proceeding with the Installation... Following packages will be installed"
sudo apt update && sudo apt upgrade -y
sudo apt install snapd
echo "Install required packages" 
echo
echo $PACKAGES
echo
sudo apt-get install -y $PACKAGES
sudo python3 -m pip install --upgrade pip
sudo -H pip3 install wheel 
sudo -H pip3 install setuptools==60.2.0 
sudo -H pip3 install setuptools-rust==1.3.0
sudo python3 -m pip install -r requirements.txt


#Function call to Install Packer and Terraform
check_and_install_packer()
echo
echo "Packer is Successfully installed"
echo
check_and_install_terraform()
echo
echo "Terraform is Successfully installed"
echo