
ansible-role-perfSONAR-psconfig-publisher
=========
https://github.com/perfsonar/ansible-role-perfsonar-psconfig-publisher


This perfSONAR role installs the psconfig publisher and publishes JSON mesh files.  It can also be used to alert testpoints, toolkits, and MadDash dashboards about published meshes with the psconfig command.

Requirements
------------

This role is meant to work with any perfSONAR supported distro:

- CentOS: http://docs.perfsonar.net/install_centos.html

- Debian/Ubuntu: http://docs.perfsonar.net/install_debian.html

  

The hosts must be manageable through Ansible including access to some Ansible modules.  We recommend that you bootstrap Ansible on your hosts prior to running this role.  This can be done manually or through roles provided by [DebOps][debops] or some bootstrap roles available on Ansible Galaxy like [robertdebock.bootstrap][rdbs] as a very first role.

  

It requires Ansible v2.5 at least.

Dependencies
------------

* [ansible-role-perfsonar-installer](https://github.com/perfsonar/ansible-role-perfsonar-installer)


Role Variables
--------------

The role variables are defined in [defaults/main.yml](https://github.com/perfsonar/ansible-role-perfsonar-psconfig-publisher/blob/master/defaults/main.yml).

 Role Tags
--------------
Some tags are used in the role, they are meant to run only or skip part of the process.  The following tags are existing:

  

- `ps::install` : only install perfSONAR packages and their dependencies

- `ps::config` : only config perfSONAR packages

- `ps::running` : running tasks



License
-------

Apache 2.0

Author Information
------------------
This role is provided by the perfSONAR team.  See http://www.perfsonar.net and https://github.com/perfsonar/ for more information.
