#!/usr/bin/env bash
# B1-1 [6/6] 스케줄러 — 진짜 crontab(cron) 사용. cron 이 없으면 00b-build-cron.sh 로 먼저 설치.
# 실행: sudo bash 06-scheduler.sh
#
# 과제 요구: "agent-admin 계정의 crontab 에 매분 실행 등록".
# 과거 이 샌드박스에는 cron 데몬 자체가 없어 60초 루프 스크립트로 **대체**했었다(라벨링된 우회).
# 이제 dcron 을 소스로 빌드해 설치하므로(00b-build-cron.sh) **진짜 crontab 등록**으로 수행한다.
# cron 이 끝내 없는 환경에서만 마지막 수단으로 루프 스케줄러를 사용한다.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

CRON_LINE="* * * * * . $AGENT_HOME/env.sh; $AGENT_HOME/bin/monitor.sh >> $AGENT_LOG_DIR/monitor.cron.log 2>&1"

# Ubuntu/Debian 의 cron 데몬 프로세스명은 cron, dcron 은 crond → 둘 다 인정
if command -v crontab >/dev/null 2>&1 && { pgrep -x crond >/dev/null 2>&1 || pgrep -x cron >/dev/null 2>&1; }; then
  MODE="real-cron"
else
  MODE="loop-fallback"
  echo "!! crontab/crond 없음 → 'sudo bash 00b-build-cron.sh' 로 설치 권장. 지금은 루프 폴백 사용."
fi

# 루프 스케줄러가 떠 있으면 항상 정리 (실 cron 과 이중 실행 방지)
pkill -f 'bin/agent-scheduler[.]sh' 2>/dev/null || true
rm -f "$AGENT_LOG_DIR/scheduler.pid"

echo "== 스케줄러 방식: $MODE =="

if [[ "$MODE" == "real-cron" ]]; then
  echo "== [1/3] agent-admin 의 crontab 에 등록 (매분) =="
  printf '%s\n' "$CRON_LINE" | crontab -u "$AGENT_ADMIN" -
  # ★ dcron 은 crontab 파일을 **root 소유일 때만** 읽어 들인다.
  #   database.c:354  if (fstat(...)==0 && sbuf.st_uid == DaemonUid)   ← DaemonUid 는 crond 의 uid(root)
  #   crontab.c:174   chown(tmp, getuid(), getgid())                   ← crontab -u 도 root 소유로 설치
  #   그래서 사용자에게 chown 해버리면 crond 가 그 파일을 **말없이 무시**한다(실측으로 확인:
  #   crond 는 떠 있고 crontab -l 에는 보이는데 잡이 한 번도 실행되지 않았다).
  chown root:crontab /var/spool/cron/crontabs/"$AGENT_ADMIN" 2>/dev/null || true
  chmod 600 /var/spool/cron/crontabs/"$AGENT_ADMIN" 2>/dev/null || true
  echo "--- crontab -l -u $AGENT_ADMIN (파일: $(stat -c '%U:%G %a' /var/spool/cron/crontabs/$AGENT_ADMIN 2>/dev/null)) ---"
  crontab -l -u "$AGENT_ADMIN"

  # dcron 은 spool 디렉터리를 1시간마다 재스캔하고, 그 외에는 cron.update 파일로만 변경을 감지한다
  # (main.c:312 주석, database.c CheckUpdates). 즉각 반영을 위해 crond 를 재시작해 초기 스캔을 시킨다.
  CRON_SVC=crond; systemctl is-active cron >/dev/null 2>&1 && CRON_SVC=cron
  if systemctl is-active "$CRON_SVC" >/dev/null 2>&1; then
    systemctl restart "$CRON_SVC" && echo "$CRON_SVC 재시작 완료 (crontab 재스캔)"
  else
    pkill -x crond 2>/dev/null || true; sleep 1
    /usr/local/sbin/crond -b -S -L /var/log/crond.log
    echo "crond 백그라운드 기동"
  fi

  echo
  echo "== [2/3] crond 상태 =="
  pgrep -a cron 2>/dev/null || true; pgrep -a crond 2>/dev/null || true
  systemctl --no-pager --lines=0 status crond 2>&1 | head -4 || true

  echo
  echo "== [3/3] 실행 확인은 07-autorun-check.sh 에서 125초간 실측 =="
else
  echo "== 루프 폴백 스케줄러 설치 (cron 미설치 환경 전용) =="
  cat > "$AGENT_HOME/bin/agent-scheduler.sh" <<EOF
#!/bin/bash
# 폴백 스케줄러: cron 데몬이 없는 환경에서 60초 주기로 monitor.sh 를 호출한다.
# cron 이 설치되면(00b-build-cron.sh) 이 스크립트는 06-scheduler.sh 가 자동으로 제거한다.
echo \$\$ > "$AGENT_LOG_DIR/scheduler.pid"
while true; do
  $AGENT_HOME/bin/monitor.sh >> "$AGENT_LOG_DIR/monitor.cron.log" 2>&1
  rc=\$?
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] monitor.sh exit=\$rc" >> "$AGENT_LOG_DIR/scheduler.log"
  sleep 60
done
EOF
  chmod 750 "$AGENT_HOME/bin/agent-scheduler.sh"; chown "$AGENT_ADMIN":"$GRP_CORE" "$AGENT_HOME/bin/agent-scheduler.sh"
  setsid runuser -u "$AGENT_ADMIN" -- bash -c "nohup $AGENT_HOME/bin/agent-scheduler.sh >/dev/null 2>&1 < /dev/null &" >/dev/null 2>&1
  sleep 2
  echo "scheduler pid: $(cat "$AGENT_LOG_DIR/scheduler.pid" 2>/dev/null || echo n/a)"
fi
echo "== SCHEDULER DONE ($MODE) =="
