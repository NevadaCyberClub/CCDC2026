#!/bin/bash

# Set up Ansible environment for head node
# Run from CCDC2026/Ansible/
sudo apt update -y
sudo apt install -y ansible sshpass

cd ssh_keys
chmod +x create_keys.sh
sed -i 's/\r$//' create_keys.sh
./create_keys.sh
cat ansible.pub
cat ansible.pub >> ~/.ssh/authorized_keys
