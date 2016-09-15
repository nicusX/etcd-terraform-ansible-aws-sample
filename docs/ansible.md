# Install components, with Ansible

If you run the Ansible playbook immediately after Terraform has finished, the Instances may be still in pending state.
The included `bootstrap.yaml` playbook waits until Bastion SSH become available.

Run Ansible commands from `./ansible` subdirectory.

```
$ ansible-playbook site.yaml
```
