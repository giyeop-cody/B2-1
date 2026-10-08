#!/usr/bin/env bash
# B1-1 [추가] 주기 실행 자동 누적 실증 — "등록 후 1~2분 내 monitor.log 에 새 라인 자동 누적"
# 실행: sudo bash 07-autorun-check.sh
set -uo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

LOG="$AGENT_LOG_DIR/monitor.log"
CRONLOG="$AGENT_LOG_DIR/monitor.cron.log"

echo "== 스케줄러 프로세스 (agent-admin 소유여야 함) =="
pgrep -af agent-scheduler.sh || echo "(없음)"
for p in $(pgrep -f agent-scheduler.sh); do ps -o pid,user,etime,cmd -p "$p" --no-headers; done

before=$(wc -l < "$LOG")
echo
echo "시작: $(date '+%F %T') · monitor.log 라인 수 = $before"
echo "125초 대기 (60초 주기 스케줄러가 최소 2회 돈다)..."
sleep 125
after=$(wc -l < "$LOG")
echo "종료: $(date '+%F %T') · monitor.log 라인 수 = $after"
echo
echo "증가분 = $((after - before)) 라인"
echo
echo "--- monitor.cron.log (스케줄러가 남긴 실행 기록) 최근 6줄 ---"
tail -6 "$CRONLOG" 2>/dev/null || echo "(없음)"
echo
echo "--- monitor.log 최근 5줄 ---"
tail -5 "$LOG"
echo
if (( after - before >= 2 )); then
  echo "[PASS] 주기 실행으로 monitor.log 자동 누적 확인 (+$((after - before)) 라인 / 125초)"
else
  echo "[FAIL] 누적 부족 (+$((after - before)) 라인)"
fi
