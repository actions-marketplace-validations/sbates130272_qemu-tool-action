# qemu-tool-action

A GitHub Action that orchestrates [`qemu-tool`](https://github.com/sbates130272/qemu-minimal) operations — `gen-vm`, `run-vm`, `compose`, and `gen-compose` — inside GitHub Actions jobs.

## Usage

```yaml
- name: Generate VM
  uses: sbates130272/qemu-tool-action@v1
  with:
    operation: gen-vm
    qemu-tool-source: ./qemu   # or omit to install from PyPI
    vm-name: my-test-vm
    release: resolute
    size: '64'
    vcpus: '4'
```

```yaml
- name: Run VM
  uses: sbates130272/qemu-tool-action@v1
  with:
    operation: run-vm
    vm-name: my-test-vm
    extra-args: --kvm
```

```yaml
- name: Start compose stack
  uses: sbates130272/qemu-tool-action@v1
  with:
    operation: compose
    stack: vfio-user-ernic-2vm
    env-file: qemu/.env
    compose-profiles: rocjitsu-vm1,rocjitsu-vm2
    compose-args: up --detach
    wait-for-healthy: 'true'
    wait-timeout: '120'
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `operation` | yes | — | `gen-vm`, `run-vm`, `compose`, or `gen-compose` |
| `env-file` | no | — | Path to a qemu-tool env-file. All non-system variables are exported to `$GITHUB_ENV`. Primary mechanism for multi-VM stacks (`VM1_NAME`, `VM2_NAME`, `VM_NAMES`, MACs, etc.). |
| `vm-name` | no | `qemu-minimal` | VM name (`--vm-name`). For single-VM operations. |
| `arch` | no | `amd64` | `amd64`, `arm64`, or `riscv64` |
| `vcpus` | no | — | Number of vCPUs |
| `vmem` | no | — | Memory in MiB |
| `images-dir` | no | `/var/lib/qemu-tool/images` | VM images directory |
| `ssh-port` | no | `2222` | Host SSH port forwarded to guest port 22 |
| `release` | no | `resolute` | Ubuntu release codename (gen-vm) |
| `size` | no | — | Disk size in GB (gen-vm) |
| `packages` | no | — | Packages manifest (gen-vm) |
| `backing-image` | no | — | OCI reference for backing qcow2 (gen-vm) |
| `backing-file` | no | — | Local path to existing qcow2 backing (gen-vm) |
| `ansible-playbook` | no | — | Ansible playbook path (gen-vm) |
| `stack` | no | `vfio-user-ernic-rocjitsu-vm` | Compose stack name |
| `compose-args` | no | — | Extra args after the compose subcommand, word-split. E.g. `up --detach` |
| `compose-profiles` | no | — | Comma-separated Docker Compose profiles. E.g. `rocjitsu-vm1,rocjitsu-vm2` |
| `wait-for-healthy` | no | `false` | Poll compose services until healthy |
| `wait-timeout` | no | `120` | Seconds to wait for health |
| `extra-args` | no | — | Additional CLI flags appended verbatim, word-split. E.g. `--dry-run --no-kvm` |
| `qemu-tool-source` | no | — | Path to a qemu-tool checkout (`pip install -e`). Overrides `qemu-tool-version`. |
| `qemu-tool-version` | no | `latest` | PyPI version to install when `qemu-tool-source` is not set |

## Outputs

| Output | Description |
|---|---|
| `vm-manifest` | JSON array: `[{"name":"vm1","ssh_port":2222,"image_path":"/path/to/vm1.qcow2"}, ...]`. `image_path` is `null` for `run-vm`. Empty array for `gen-compose`. |

### Multi-VM manifest

For multi-VM compose stacks the manifest contains one entry per VM. SSH ports and VM names are read from env-file variables that were loaded into `$GITHUB_ENV`:

- Scale-out: `VM_NAMES` (comma-list) and `VM_SSH_PORTS`
- Two-VM: `VM1_NAME`/`VM2_NAME` and `VM1_SSH_PORT`/`VM2_SSH_PORT`
- Single-VM: `VM_NAME` or the `vm-name` input

```yaml
- name: Start two-VM stack
  id: two_vm
  uses: sbates130272/qemu-tool-action@v1
  with:
    operation: compose
    env-file: qemu/.env           # contains VM1_NAME, VM2_NAME, VM1_SSH_PORT, VM2_SSH_PORT
    stack: vfio-user-ernic-2vm
    compose-args: up --detach

- name: Print SSH ports
  run: |
    echo '${{ steps.two_vm.outputs.vm-manifest }}' | python3 -c "
    import json, sys
    for vm in json.load(sys.stdin):
        print(f'{vm[\"name\"]}: ssh -p {vm[\"ssh_port\"]} localhost')
    "
```

## MAC addresses and netplan

MAC addresses are not action inputs. Since `qemu-tool gen-vm` commit `3969f07`, generated images use netplan interface-name matching (not MAC matching), so `VM_MAC` is not needed for images built by current versions. For images that do require a specific MAC, pass it via `env-file` (`VM_MAC=XX:XX:XX:XX:XX:XX`) or via `extra-args: --mac XX:XX:XX:XX:XX:XX`.

Ernic mesh MACs (`ERNIC1_MAC`, `ERNIC2_MAC`, per-VM MACs in scale-out) belong in the env-file and are consumed by the compose stack directly — the action passes them through transparently.

## Versioning

Tags follow the three-tag convention: `v1.0.0` (exact), `v1.0` (floating minor), `v1` (floating major). The release workflow keeps the floating tags up to date on every release.

## Integration with `qemu-minimal`

This action is complementary to the `setup-vm-job` composite action in `qemu-minimal`, which handles KVM verification, pip caching, SSH key generation, Ansible collection caching, and cloud image caching. Use `setup-vm-job` first, then use this action for the `qemu-tool` invocations:

```yaml
    - uses: ./.github/actions/setup-vm-job
      with:
        cloud-image-key: ernic
        images-dir: /var/lib/qemu-tool/images

    - uses: sbates130272/qemu-tool-action@v1
      with:
        operation: gen-vm
        qemu-tool-source: ./qemu   # already installed by setup-vm-job, this is a no-op
        vm-name: ernic-test
        ansible-playbook: ansible/playbooks/vm-ernic.yml
```

## License

MIT
