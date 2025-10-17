Hello [CISO],

Here is our automated solution for logging all installed applications across all hosts in our network using Ansible Playbooks.

##Step 1: Install Ansible following the commands below.##

##Step 2: Generate SSH keys on managed nodes, then add the public key to authorized_keys on the Ansible server.##

You can confirm that Ansible is functioning on various hosts by running the following command:

The sample screenshot below shows confirmation of the functioning host [host ip].

##Step 3: List of all installed Applications that are logged.##

The screenshot below shows applications on our system include ImageMagick, Network-Manager, and other applications that were installed.

Support for Various Systems

It is important that this Ansible system works across the various operating systems within our infrastructure. The following screenshots depict the playbook running across all operating systems. Refer to the “Windows Section” and “Linux / Unix Section”.

Thank you,
Team [Team number]





