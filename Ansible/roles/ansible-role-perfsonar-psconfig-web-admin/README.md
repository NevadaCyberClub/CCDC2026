# ansible-role-perfsonar-psconfig-web-admin
Install and configure a perfSONAR psconfig web admin site

This is integrated with the master perfSONAR Ansible playbook found here:

<https://github.com/perfsonar/ansible-playbook-perfsonar>

Please see the role 
[defaults/main.yml](https://github.com/perfsonar/ansible-role-perfsonar-psconfig-web-admin/blob/master/defaults/main.yml)
for documentation on variables and how to use them.

---

**Some useful commands to manage the PWA environment**

Display PWA users:
```
ansible ps-psconfig-web-admin \
  -a "docker exec -it sca-auth pwa_auth listuser --short"
```

Display PWA users, all atributes:
```
ansible ps-psconfig-web-admin \
  -a "docker exec -it sca-auth pwa_auth listuser"
```

Reset Password for PWA user from the command line:
```
ansible ps-psconfig-web-admin \
  -a "docker exec -it sca-auth pwa_auth setpass \
  --username user --password newpasswd"
```

Reset Password for PWA user interactively:
```
ansible-playbook \
  roles/ansible-role-perfsonar-psconfig-web-admin/playbooks/pwa_passwd_reset.yml
```
