#!/usr/bin/env bash
# B1-1 [5/6] monitor.sh 배치 (소유 agent-dev · 그룹 agent-core · 750) + 실행 검증
# 실행: sudo bash 05-monitor-install.sh
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

BIN_DIR="$AGENT_HOME/bin"

echo "== [1/4] monitor.sh 배치: 원본(참고용) + 이 환경용 수정본 =="
[[ -f "$B11_MONITOR_SRC" ]] || { echo "원본 없음: $B11_MONITOR_SRC"; exit 1; }
install -m 750 -o "$AGENT_DEV" -g "$GRP_CORE" "$B11_MONITOR_SRC" "$BIN_DIR/monitor.sh.orig"
install -m 750 -o "$AGENT_DEV" -g "$GRP_CORE" "$B11_REPORT_SRC"  "$BIN_DIR/report.sh"
# 이 환경용 수정본(lab/scripts/monitor.sh) 설치 — 수정 사유 2가지:
#   FIX-1: 이 이미지에는 bc 가 없다(command -v bc → 없음). 원본의 임계값 비교는 bc 를 쓰므로
#          그대로 두면 임계값 경고가 영원히 동작하지 않는다 → awk 로 치환.
#   FIX-2: 원본의 마지막 fallback `pgrep -f agent-app` 이 부분문자열 매칭이라, B1-2 로 앱을
#          교체한 뒤 스케줄러 자기 자신을 앱으로 잡아 monitor.log 에 잘못된 PID 를 기록했다
#          (실측: PID:2420 = agent-scheduler.sh) → comm 정확 일치(-x) 우선으로 변경.
install -m 750 -o "$AGENT_DEV" -g "$GRP_CORE" "$(dirname "$0")/monitor.sh" "$BIN_DIR/monitor.sh"

echo "--- bc 존재 여부 ---"; command -v bc || echo "bc: MISSING (이 이미지에는 없음)"
echo "--- 원본(monitor.sh.orig) vs 이 환경용(monitor.sh) 차이 ---"
diff "$BIN_DIR/monitor.sh.orig" "$BIN_DIR/monitor.sh" || true

echo
echo "== [2/4] 소유/권한 검증 (agent-dev:agent-core 750) =="
ls -l "$BIN_DIR"
stat -c '%n owner=%U group=%G mode=%a' "$BIN_DIR/monitor.sh"

echo
echo "== [3/4] cron 실행 계정(agent-admin) 실행 가능 여부 =="
echo "agent-admin 그룹: $(id -nG "$AGENT_ADMIN")"
echo "bin 디렉토리: $(stat -c '%U:%G %a' "$BIN_DIR")"
if runuser -u "$AGENT_ADMIN" -- test -x "$BIN_DIR/monitor.sh"; then
  echo "agent-admin: 실행 권한 OK (agent-core 소속으로 750 스크립트 실행 가능)"
else
  echo "agent-admin: 실행 권한 없음 → agent-core 소속/디렉토리 탐색 권한 확인 필요"
fi

echo
echo "== [4/4] 원본 그대로 1회 실행 (bc 부재 증상 기록용) =="
runuser -u "$AGENT_ADMIN" -- bash -c ". '$AGENT_HOME/env.sh'; '$BIN_DIR/monitor.sh.orig'" 2>&1 | tail -12 || \
  echo "(exit=$?)"

echo
echo "== [4/4] 이 환경용 monitor.sh 1회 실행 =="
runuser -u "$AGENT_ADMIN" -- bash -c ". '$AGENT_HOME/env.sh'; '$BIN_DIR/monitor.sh'" || \
  echo "(exit=$? — 헬스체크 실패 시 1 반환이 정상 동작)"
echo
echo "--- monitor.log 최근 5줄 ---"
tail -5 "$AGENT_LOG_DIR/monitor.log" 2>/dev/null || echo "(아직 없음)"
echo
echo "== MONITOR INSTALL DONE =="
