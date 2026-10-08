#!/usr/bin/env bash
# B1-2 [1/3] 같은 VM 에 agent-leak-app 배치 (B1-1 환경을 수정해 재사용)
# 실행: sudo bash 10-deploy-leak-app.sh
#
# B1-1 과 B1-2 는 별도 VM 이 아니다. B1-1 에서 만든 계정/그룹/권한/디렉토리/로그/방화벽/스케줄러를
# 그대로 두고, 실행 대상 앱만 agent-app → agent-leak-app 으로 교체한다.
#  - 두 앱 모두 0.0.0.0:15034 를 요구하므로 B1-1 앱은 먼저 종료해야 한다(부트 [4/5] 포트 검사).
#  - B1-2 부트 조건표는 AGENT_KEY_PATH = $AGENT_HOME/api_keys(디렉토리) + secret.key 를 요구한다
#    → B1-1 에서 이미 만들어 둔 그 파일이 그대로满足된다.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

echo "== [1/5] B1-1 앱(agent-app) 종료 — 포트 15034 확보 =="
pgrep -af '/usr/local/bin/agent-app' || echo "(실행 중 아님)"
pkill -f '/usr/local/bin/agent-app' 2>/dev/null || true
sleep 2
ss -tln | grep ":$AGENT_PORT" && { echo "포트 아직 점유됨"; exit 1; } || echo "포트 $AGENT_PORT 비어 있음"

echo
echo "== [2/5] agent-leak-app 배치: $B12_APP =="
[[ -f "$B12_APP_SRC" ]] || { echo "원본 없음: $B12_APP_SRC"; exit 1; }
install -m 755 -o "$AGENT_ADMIN" -g "$GRP_COMMON" "$B12_APP_SRC" "$B12_APP"
ls -l "$B12_APP"

echo
echo "== [3/5] B1-2 프로세스 관제 스크립트 배치 (B1-1 monitor.sh 와 별개) =="
install -m 750 -o "$AGENT_DEV" -g "$GRP_CORE" "$B12_PROCMON_SRC" "$B12_PROCMON"
install -m 750 -o "$AGENT_DEV" -g "$GRP_CORE" "$B12_STACKTRACE" "$AGENT_HOME/bin/capture-stacktrace.sh"
ls -l "$AGENT_HOME/bin"

echo
echo "== [4/5] B1-1 에서 물려받은 것들 그대로인지 확인 =="
id "$AGENT_ADMIN"
ls -ld "$AGENT_HOME" "$AGENT_UPLOAD_DIR" "$AGENT_KEYS_DIR" "$AGENT_LOG_DIR"
ls -l "$AGENT_KEYS_DIR"
echo "SSH: $(/usr/sbin/sshd -T 2>/dev/null | grep -E '^port ')"
echo "방화벽: $(iptables -S INPUT 2>/dev/null | head -1)"
echo "스케줄러: $(ps -o pid=,user=,cmd= -p "$(cat "$AGENT_LOG_DIR/agent-scheduler.pid" 2>/dev/null)" 2>/dev/null || echo '미가동')"

echo
echo "== [5/5] 부트 조건 만족 여부 드라이런 (5초) =="
runuser -u "$AGENT_ADMIN" -- bash -c "
  . '$AGENT_HOME/env.sh'
  export MEMORY_LIMIT=512 CPU_MAX_OCCUPY=50 MULTI_THREAD_ENABLE=false
  timeout 5 '$B12_APP' 2>&1 | sed -n '1,20p'
" || true
echo
echo "== DEPLOY DONE =="
