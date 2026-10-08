#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
[[ $EUID == 0 ]] || { echo 'Run as root'; exit 1; }
source /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 && $(uname -m) == x86_64 ]] || { echo 'Ubuntu 24.04 amd64 required'; exit 1; }
export LAB_SRC="$ROOT/inputs" CONTROL_PORT=""
mkdir -p "$ROOT/output" "$ROOT/B1-1/lab/evidence" "$ROOT/B1-2/lab/evidence"
stop_apps() {
 systemctl stop codyssey-b1-1 codyssey-b1-2 2>/dev/null || true
 pkill -f '/usr/local/bin/[a]gent-app' || true
 pkill -f '/home/agent-admin/agent-app/[a]gent-leak-app' || true
 sleep 1
}
units() {
 for mode in 1 2; do
  other=$((3-mode))
  if [[ $mode == 1 ]]; then app=/usr/local/bin/agent-app; else app=/home/agent-admin/agent-app/agent-leak-app; fi
  cat > "/etc/systemd/system/codyssey-b1-$mode.service" <<EOF
[Unit]
Description=Codyssey B1-$mode application
After=network.target
Conflicts=codyssey-b1-$other.service
[Service]
Type=simple
User=agent-admin
WorkingDirectory=/home/agent-admin/agent-app
Environment=MEMORY_LIMIT=512 CPU_MAX_OCCUPY=50 MULTI_THREAD_ENABLE=false
ExecStart=/bin/bash -c '. /home/agent-admin/agent-app/env.sh; exec $app'
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
 done
 systemctl daemon-reload
}
activate_b11() {
 stop_apps
 systemctl disable codyssey-b1-2 2>/dev/null || true
 systemctl enable --now codyssey-b1-1
 sleep 3
}
verify() {
 bash "$ROOT/B1-1/lab/scripts/verify-all.sh" | tee "$ROOT/output/b1-1-verification.txt"
 grep -Eq 'PASS.*36.*FAIL.*0' "$ROOT/output/b1-1-verification.txt"
}
case ${1:-status} in
 setup)
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y openssh-server ufw acl cron bc git procps psmisc gzip jq nftables iproute2 sudo python3 gdb strace
  timedatectl set-timezone Asia/Seoul
  systemctl enable --now cron
  systemctl disable --now ssh.socket || true
  systemctl stop ssh || true
  stop_apps
  bash "$ROOT/B1-1/lab/scripts/run-all.sh" | tee "$ROOT/output/setup.txt"
  grep -q '\[PASS\] 주기 실행으로' "$ROOT/output/setup.txt"
  pkill -x sshd || true
  systemctl enable --now ssh
  units
  activate_b11
  verify
  ;;
 switch)
  test -f "$ROOT/output/b1-1-verification.txt"
  stop_apps
  bash "$ROOT/B1-2/lab/scripts/10-deploy-leak-app.sh" | tee "$ROOT/output/transition.txt"
  stop_apps
  systemctl disable codyssey-b1-1
  systemctl enable --now codyssey-b1-2
  sleep 3
  systemctl is-active codyssey-b1-2
  journalctl -u codyssey-b1-2 --no-pager -n 150 | tee "$ROOT/output/b1-2-service.txt"
  grep -q 'Agent READY' "$ROOT/output/b1-2-service.txt"
  ss -tln | grep ':15034'
  ;;
 restore)
  stop_apps
  bash "$ROOT/B1-2/lab/scripts/30-restore-b1-1.sh" | tee "$ROOT/output/restore.txt"
  activate_b11
  verify
  ;;
 experiments)
  stop_apps
  bash "$ROOT/B1-2/lab/scripts/10-deploy-leak-app.sh"
  for phase in before after; do
   for scenario in oom cpu deadlock; do bash "$ROOT/B1-2/lab/scripts/20-run-scenario.sh" "$scenario" "$phase"; done
  done
  bash "$ROOT/B1-2/lab/scripts/40-scheduling-probe.sh"
  bash "$0" restore
  ;;
 finalize)
  grep -q "\[PASS\] 주기 실행으로" "$ROOT/output/setup.txt"
  pkill -x sshd || true
  systemctl enable --now ssh
  units
  activate_b11
  verify
  ;;
 verify) verify ;;
 status) systemctl --no-pager status codyssey-b1-1 codyssey-b1-2 ssh cron || true; ss -tln ;;
 *) echo 'setup|switch|restore|experiments|verify|status'; exit 2 ;;
esac
