# telegraf-deployment


## Bulid the container:

```bash
export DOCKERHUB_USERNAME=<your_username>
./build_container.sh
```

## How to deploy everything:

> Reporducibility disclaimer: In the `templates/telegraf-config.toml.j2` file, you may need to adjust the db url accordingly to your setup. 
> Obviously, you also need to adjust the inventory file to match your setup.

```
ansible-playbook --key-file=$HOME/.ssh/<your_key> install.yaml
```

To remove all the running containers:

```
ansible-playbook --key-file=$HOME/.ssh/<your_key> remove.yaml
```


And then deploy the content of the `server-wide-metrics` directory with

### Manual install

- build the container
- populate the /etc/containers/systemd/<file>.container
- `systemctl daemon-reload`
- `systemctl start <file>.service`

Debug the generated unit with `/usr/libexec/podman/quadlet --dryrun <file>.container`

