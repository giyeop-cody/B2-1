#!/usr/bin/env bash
# B1-2 [3/3] B1-1 상태로 되돌리기 (같은 VM 을 다시 B1-1 운영 환경으로)
# 실행: sudo bash 30-restore-b1-1.sh
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

echo "== leak-app 종료 =="
pkill -f "$B12_APP" 2>/dev/null || true
pkill -f "$B12_PROCMON" 2>/dev/null || true
sleep 2

echo "== B1-1 agent-app 재기동 =="
bash "$B1_REPO_ROOT/B1-1/lab/scripts/04-app-run.sh" | tail -8

echo "== B1-1 체크리스트 재검증 =="
bash "$B1_REPO_ROOT/B1-1/lab/scripts/verify-all.sh" | tail -12
echo "== RESTORE DONE =="
