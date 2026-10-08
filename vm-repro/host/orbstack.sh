#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VM=${VM_NAME:-codyssey-b1-repro}
ACTION=${1:-setup}
ORB=${ORB:-$HOME/.orbstack/bin/orb}
case $ACTION in
 setup)
  if ! "$ORB" list -q | grep -Fxq "$VM"; then "$ORB" create -a amd64 ubuntu:24.04 "$VM"; fi
  "$ORB" -m "$VM" -u root mkdir -p /root/codyssey-vm
  tar -C "$ROOT" --exclude=./output -cf - . | "$ORB" -m "$VM" -u root tar -xf - -C /root/codyssey-vm
  "$ORB" -m "$VM" -u root bash /root/codyssey-vm/guest/lab.sh setup
  ;;
 export)
  DEST="$ROOT/output/$VM"; mkdir -p "$DEST"
  "$ORB" -m "$VM" -u root tar -C /root/codyssey-vm -cf - output B1-2/lab/evidence | tar -C "$DEST" -xf -
  echo "$DEST"
  ;;
 switch|restore|experiments|verify|status) "$ORB" -m "$VM" -u root bash /root/codyssey-vm/guest/lab.sh "$ACTION" ;;
 *) echo 'setup|switch|restore|experiments|verify|status|export'; exit 2 ;;
esac
