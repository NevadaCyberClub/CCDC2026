# perfsonar-deployment

scripts and playbooks to help with easy deployment of perfsonar

> initially sourced from: [perfsonar-playbook](https://github.com/perfsonar/ansible-playbook-perfsonar)

## Setup

Individual host variables with the `lsregistration.yml` template:

```bash
mkdir host_vars/myhostname
cp roles/ansible-role-perfsonar-testpoint/defaults/lsregistration.yml host_vars/myhostname
vim inventory/host_vars/myhostname/lsregistration.yml
```

Edit default `lsregistration.yml` template:

```bash
vim roles/ansible-role-perfsonar-testpoint/defaults/lsregistration.yml
```

## Topology

A single central perfsonar node is configured with: ps web admin, ps archive, and ps grafana

Many testpoint perfsonar nodes are configured to connect to the central perfsonar node

## Important variables

allowed_networks: networks which are allowed to access port 80 and 443 on the perfsonar central node
location: roles/perfsonar-maininstall/defaults/

archive_hostname: hostname of the perfsonar central node for testpoints to archive data to, must be reachable by testpoints
location: host_vars/central-perfsonar-archive.re.nevada.internal.yml

perfsonar_psconfig_remote_remotes: remote url that testpoints get psconfig file from
location: group_vars/ps_testpoint.yml

## Run the playbook

### Archive Node

```bash
ansible-playbook -i hosts.ini perfsonar.yml --tags=archive --vault-password-file=./.vault-pass -v
```

### Frontend Node (In Progress)

```bash
ansible-playbook -i hosts.ini perfsonar.yml --tags=frontend --vault-password-file=./.vault-pass -v
```

### Ansible Tags Definitions

- setup-archive: only sets up archive node
- archive: sets up archive node and configures archive node for testpoints
- all-testpoints: setup baremetal testpoints, sets up docker testpoints, setup archive node for testpoints
- setup-baremetal-testpoints: setup baremetal testpoints, setup archive node for testpoints
- install-baremetal-testpoints: only setup baremetal testpoints
- setup-docker-testpoints: setup docker testpoints, setup archive node for testpoints
- install-docker-testpoints: only setup docker testpoints
- webadmin: setup psconfig web admin
