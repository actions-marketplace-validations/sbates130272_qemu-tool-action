#!/usr/bin/env bash
# Assemble the vm-manifest JSON output from QT_* and env-file-exported variables.
set -euo pipefail

python3 - <<'PY'
import os, json, pathlib

operation  = os.environ.get('QT_OPERATION', '')
images_dir = os.environ.get('QT_IMAGES_DIR', '/var/lib/qemu-tool/images')

def find_image(name):
    p = pathlib.Path(images_dir) / f"{name}.qcow2"
    return str(p) if p.exists() else None

manifest = []

if operation == 'gen-compose':
    pass  # no VMs created directly

elif operation in ('gen-vm', 'run-vm'):
    name     = os.environ.get('QT_VM_NAME', 'qemu-minimal')
    ssh_port = int(os.environ.get('QT_SSH_PORT', '2222'))
    image    = find_image(name) if operation == 'gen-vm' else None
    manifest.append({'name': name, 'ssh_port': ssh_port, 'image_path': image})

elif operation == 'compose':
    # Priority 1: VM_NAMES comma-list (scale-out fleet, env.scale-out)
    vm_names_raw  = os.environ.get('VM_NAMES', '')
    ssh_ports_raw = os.environ.get('VM_SSH_PORTS', '')

    # Priority 2: VM1_NAME / VM2_NAME (two-VM ernic stack)
    vm1_name = os.environ.get('VM1_NAME', '')
    vm2_name = os.environ.get('VM2_NAME', '')
    vm1_port = os.environ.get('VM1_SSH_PORT', '')
    vm2_port = os.environ.get('VM2_SSH_PORT', '')

    # Priority 3: single VM (VM_NAME or QT_VM_NAME)
    vm_name  = os.environ.get('VM_NAME', os.environ.get('QT_VM_NAME', 'qemu-minimal'))
    vm_port  = int(os.environ.get('VM_SSH_PORT', os.environ.get('QT_SSH_PORT', '2222')))

    if vm_names_raw:
        names = [n.strip() for n in vm_names_raw.split(',') if n.strip()]
        ports = [int(p.strip()) for p in ssh_ports_raw.split(',') if p.strip()] if ssh_ports_raw else []
        for i, name in enumerate(names):
            port = ports[i] if i < len(ports) else vm_port + i
            manifest.append({'name': name, 'ssh_port': port, 'image_path': find_image(name)})
    elif vm1_name and vm2_name:
        p1 = int(vm1_port) if vm1_port else 2222
        p2 = int(vm2_port) if vm2_port else 2223
        manifest.append({'name': vm1_name, 'ssh_port': p1, 'image_path': find_image(vm1_name)})
        manifest.append({'name': vm2_name, 'ssh_port': p2, 'image_path': find_image(vm2_name)})
    else:
        manifest.append({'name': vm_name, 'ssh_port': vm_port, 'image_path': find_image(vm_name)})

result = json.dumps(manifest)
print(f"vm-manifest={result}", file=open(os.environ['GITHUB_OUTPUT'], 'a'))
print(f"VM manifest: {result}")
PY
