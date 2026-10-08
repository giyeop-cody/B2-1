#!/usr/bin/env bash
# B1-1 [4/6] 제공 앱(agent-app) 배치 + 일반 계정으로 실행 + 부트시퀀스/리슨 검증
# 실행: sudo bash 04-app-run.sh
#   (앱 프로세스 자체는 root 가 아니라 agent-admin 소유로 떠야 한다 — 미션 요구사항)
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

BIN=/usr/local/bin/agent-app
CONSOLE="$AGENT_LOG_DIR/agent_app.console.log"

echo "== [1/3] 바이너리 배치: $BIN =="
[[ -f "$B11_APP_SRC" ]] || { echo "원본 바이너리 없음: $B11_APP_SRC"; exit 1; }
install -m 755 -o root -g root "$B11_APP_SRC" "$BIN"
ls -l "$BIN"
head -c 4 "$BIN" | od -An -c | head -1

echo
echo "== [2/3] agent-admin 계정으로 백그라운드 실행 (루트 실행 금지) =="
# 이미 떠 있으면 정리
pkill -f "/usr/local/bin/agent-app" 2>/dev/null || true
sleep 1
: > "$CONSOLE"
chown "$AGENT_ADMIN:$GRP_CORE" "$CONSOLE"
runuser -u "$AGENT_ADMIN" -- bash -c "
  set -e
  . '$AGENT_HOME/env.sh'
  cd '$AGENT_HOME'
  setsid nohup '$BIN' >> '$CONSOLE' 2>&1 < /dev/null &
  echo \"started pid=\$!\"
"

echo
echo "== [3/3] 부트 시퀀스 / 리슨 검증 (최대 30초 대기) =="
ok=0
for i in $(seq 1 30); do
  if grep -q 'Agent READY' "$CONSOLE" 2>/dev/null; then ok=1; break; fi
  sleep 1
done
echo "--- 부트 시퀀스 구간 ---"
sed -n '/Starting Agent Boot Sequence/,/Agent READY/p' "$CONSOLE"
echo "--- [OK] 카운트: $(grep -c '\[OK\]' "$CONSOLE" || true) ---"
[[ $ok -eq 1 ]] && echo "Agent READY: 확인" || { echo "Agent READY: 미확인 — 콘솔 로그 확인 필요"; tail -30 "$CONSOLE"; exit 1; }

echo "--- 프로세스 소유자 (root 아님 확인) ---"
ps -o pid,user,group,etime,cmd -p "$(pgrep -f '/usr/local/bin/agent-app' | head -1)"
echo "--- 리슨 상태 ---"
ss -tulnp | grep ":$AGENT_PORT" || { echo "LISTEN 없음"; exit 1; }
echo
echo "== APP RUN DONE =="
