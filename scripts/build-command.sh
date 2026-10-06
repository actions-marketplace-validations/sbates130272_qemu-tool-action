#!/usr/bin/env bash
# Assemble and execute a qemu-tool CLI invocation from QT_* environment variables.
# Variables are set by the action.yml step that calls this script.
set -euo pipefail

CMD=(qemu-tool "$QT_OPERATION")

case "$QT_OPERATION" in

  gen-vm)
    CMD+=(--vm-name  "$QT_VM_NAME")
    CMD+=(--arch     "$QT_ARCH")
    CMD+=(--images   "$QT_IMAGES_DIR")
    CMD+=(--ssh-port "$QT_SSH_PORT")
    CMD+=(--release  "$QT_RELEASE")
    [ -n "$QT_VCPUS"            ] && CMD+=(--vcpus            "$QT_VCPUS")
    [ -n "$QT_VMEM"             ] && CMD+=(--vmem             "$QT_VMEM")
    [ -n "$QT_SIZE"             ] && CMD+=(--size             "$QT_SIZE")
    [ -n "$QT_PACKAGES"         ] && CMD+=(--packages         "$QT_PACKAGES")
    [ -n "$QT_BACKING_IMAGE"    ] && CMD+=(--backing-image    "$QT_BACKING_IMAGE")
    [ -n "$QT_BACKING_FILE"     ] && CMD+=(--backing-file     "$QT_BACKING_FILE")
    [ -n "$QT_ANSIBLE_PLAYBOOK" ] && CMD+=(--ansible-playbook "$QT_ANSIBLE_PLAYBOOK")
    ;;

  run-vm)
    CMD+=(--vm-name  "$QT_VM_NAME")
    CMD+=(--arch     "$QT_ARCH")
    CMD+=(--images   "$QT_IMAGES_DIR")
    CMD+=(--ssh-port "$QT_SSH_PORT")
    [ -n "$QT_VCPUS" ] && CMD+=(--vcpus "$QT_VCPUS")
    [ -n "$QT_VMEM"  ] && CMD+=(--vmem  "$QT_VMEM")
    ;;

  compose)
    CMD+=(--vm-name "$QT_VM_NAME")
    CMD+=(--images  "$QT_IMAGES_DIR")
    CMD+=(--stack   "$QT_STACK")
    # Collect docker-compose passthrough: profile flags first, then subcommand args.
    # These go after the "--" separator that separates qemu-tool flags from
    # docker-compose flags (matching the pattern in qemu-minimal workflows).
    PASSTHROUGH=()
    if [ -n "$QT_COMPOSE_PROFILES" ]; then
      IFS=',' read -ra PROFILES <<< "$QT_COMPOSE_PROFILES"
      for p in "${PROFILES[@]}"; do
        PASSTHROUGH+=(--profile "$p")
      done
    fi
    if [ -n "$QT_COMPOSE_ARGS" ]; then
      read -ra COMPOSE_PASS <<< "$QT_COMPOSE_ARGS"
      PASSTHROUGH+=("${COMPOSE_PASS[@]}")
    fi
    [ "${#PASSTHROUGH[@]}" -gt 0 ] && CMD+=(-- "${PASSTHROUGH[@]}")
    ;;

  gen-compose)
    CMD+=(--stack "$QT_STACK")
    ;;

  *)
    echo "::error::Unknown operation: $QT_OPERATION"
    echo "::error::Must be one of: gen-vm, run-vm, compose, gen-compose"
    exit 1
    ;;
esac

# Append extra-args (word-split; callers are responsible for quoting within the string)
if [ -n "$QT_EXTRA_ARGS" ]; then
  read -ra EXTRA <<< "$QT_EXTRA_ARGS"
  CMD+=("${EXTRA[@]}")
fi

echo "Running: ${CMD[*]}"
exec "${CMD[@]}"
