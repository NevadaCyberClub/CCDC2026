#!/bin/bash

# Set up Ansible environment for head node
cd ../..
sudo apt install python3.12-venv -y
python3 -m venv venv
source venv/bin/activate
pip install ansible
cd CCDC2026/Ansible/ssh_keys
chmod +x create_keys.sh
sed -i 's/\r$//' create_keys.sh
./create_keys.sh
cat ansible.pub
cat ansible.pub >> ~/.ssh/authorized_keys
