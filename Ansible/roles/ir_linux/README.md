# ansible-velociraptor (Linux)
Ansible role for Velociraptor EDR

## Usage

To use this role in your playbook to install the server, add the code below:

```
- name: Install Velociraptor EDR
  import_role:
    name: ansible-velociraptor
  vars:
    server: true
```

To use this role in your playbook to install the client, add the code below:

```
- name: Install Velociraptor EDR
  import_role:
    name: ansible-velociraptor
  vars:
    client: true
```

## License

[MIT](LICENSE)
