# ansible-velociraptor
Ansible role for Velociraptor EDR (Windows)

## Usage

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
