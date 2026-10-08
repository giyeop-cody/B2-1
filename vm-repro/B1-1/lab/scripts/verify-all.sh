#!/usr/bin/env bash
# B1-1 필수 증거 체크리스트 자동 검증
# 실행: sudo bash verify-all.sh  (출력을 evidence/verification.txt 로 남긴다)
set -uo pipefail
source "$(dirname "$0")/00-env.sh"

pass=0; fail=0
chk() { # chk <설명> <조건 명령>
  # 서브셸에서 pipefail 을 끈다: `sshd -T | grep -q` 는 grep 이 먼저 끝나면서 sshd 가 SIGPIPE(141)
  # 로 죽는데, pipefail 이 켜져 있으면 성공 조건도 실패로 잡힌다(실측으로 확인한 함정).
  if ( set +o pipefail; eval "$2" ) >/dev/null 2>&1; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1"; fail=$((fail+1)); fi
}

echo "############ B1-1 VERIFICATION $(date '+%F %T') ############"
echo
echo "--- 1. SSH ---"
echo "sshd -T 실효값:"; /usr/sbin/sshd -T 2>/dev/null | grep -Ei '^(port|permitrootlogin) '
echo "리슨:"; ss -tulnp 2>/dev/null | grep -E ':20022|:22 ' || echo "(없음)"
chk "SSH 포트 20022"            "/usr/sbin/sshd -T 2>/dev/null | grep -q '^port $SSH_PORT'"
chk "PermitRootLogin no"        "/usr/sbin/sshd -T 2>/dev/null | grep -q '^permitrootlogin no'"
chk "20022 리슨"                "ss -tln 2>/dev/null | grep -q ':$SSH_PORT'"

echo
echo "--- 2. 방화벽 ---"
if command -v ufw >/dev/null 2>&1; then
  echo "ufw: $(ufw version 2>&1 | head -1)"
  ufw status verbose 2>/dev/null
  ufw status numbered 2>/dev/null
  chk "ufw 활성"                 "ufw status | grep -q 'Status: active'"
  chk "ufw 기본 인바운드 deny"    "ufw status verbose | grep -qi 'Default: deny (incoming)'"
  chk "ufw 20022/tcp(SSH) 허용"   "ufw status | grep -Eq '^$SSH_PORT/tcp .*ALLOW'"
  chk "ufw 15034/tcp(APP) 허용"   "ufw status | grep -Eq '^$AGENT_PORT/tcp .*ALLOW'"
  # ufw status 는 v4/v6 를 따로 표시한다 → v6 줄을 빼고 샌다
  # (주의: 일반 'ufw status' 는 "ALLOW", 'ufw status verbose' 는 "ALLOW IN" 으로 표기한다 — 실측)
  ALLOW_N="$(ufw status | grep 'ALLOW' | grep -vc 'v6')"
  EXPECTED_ALLOW=2
  [[ -n ${CONTROL_PORT-49983} ]] && EXPECTED_ALLOW=3
  echo "ufw v4 허용 규칙 수: $ALLOW_N (기대: $EXPECTED_ALLOW)"
  chk "ufw 허용 규칙 수가 환경별 정책과 일치" "[ $ALLOW_N -eq $EXPECTED_ALLOW ]"
else
  echo "(ufw 미설치 → iptables 폴백 상태 검사)"
  iptables -S INPUT 2>/dev/null
  ALLOW_DPORTS="$(iptables -S INPUT 2>/dev/null | grep -o -- '--dport [0-9]*' | awk '{print $2}' | sort -n | uniq | tr '\n' ' ')"
  echo "허용된 dport 목록: $ALLOW_DPORTS"
  chk "INPUT 기본 정책 DROP"      "iptables -S INPUT | grep -q '^-P INPUT DROP'"
  chk "20022(SSH) 허용 규칙"      "iptables -S INPUT | grep -q -- '--dport $SSH_PORT .*-j ACCEPT'"
  chk "15034(APP) 허용 규칙"      "iptables -S INPUT | grep -q -- '--dport $AGENT_PORT .*-j ACCEPT'"
  # 49983 은 이 샌드박스의 제어 채널(envd) 예외다. 실서비스 VM 에서는 20022/15034 두 개만 남아야 한다.
  chk "허용 dport = 15034 20022 49983(샌드박스 예외) 뿐" "[ \"$ALLOW_DPORTS\" = '15034 20022 49983 ' ]"
fi

echo
echo "--- 3. 계정/그룹 ---"
for u in "$AGENT_ADMIN" "$AGENT_DEV" "$AGENT_TEST"; do id "$u" 2>/dev/null; done
getent group "$GRP_COMMON" "$GRP_CORE"
chk "agent-admin 존재"          "id -u $AGENT_ADMIN"
chk "agent-dev 존재"            "id -u $AGENT_DEV"
chk "agent-test 존재"           "id -u $AGENT_TEST"
chk "agent-common = admin,dev,test" "getent group $GRP_COMMON | grep -q $AGENT_ADMIN && getent group $GRP_COMMON | grep -q $AGENT_DEV && getent group $GRP_COMMON | grep -q $AGENT_TEST"
chk "agent-core = admin,dev"    "getent group $GRP_CORE | grep -q $AGENT_ADMIN && getent group $GRP_CORE | grep -q $AGENT_DEV && ! getent group $GRP_CORE | grep -q $AGENT_TEST"

echo
echo "--- 4. 디렉토리/권한 ---"
ls -ld "$AGENT_HOME" "$AGENT_UPLOAD_DIR" "$AGENT_KEYS_DIR" "$AGENT_LOG_DIR" "$AGENT_HOME/bin" 2>/dev/null
ls -l "$AGENT_KEYS_DIR" 2>/dev/null
chk "upload_files group=agent-common 770" "[ \"\$(stat -c %G $AGENT_UPLOAD_DIR)\" = $GRP_COMMON ] && [ \"\$(stat -c %a $AGENT_UPLOAD_DIR)\" = 770 ]"
chk "api_keys group=agent-core 770"       "[ \"\$(stat -c %G $AGENT_KEYS_DIR)\" = $GRP_CORE ] && [ \"\$(stat -c %a $AGENT_KEYS_DIR)\" = 770 ]"
chk "/var/log/agent-app group=agent-core 770" "[ \"\$(stat -c %G $AGENT_LOG_DIR)\" = $GRP_CORE ] && [ \"\$(stat -c %a $AGENT_LOG_DIR)\" = 770 ]"
chk "키 파일 내용 = agent_api_key_test"   "grep -q agent_api_key_test $AGENT_KEYS_DIR/secret.key"

echo
echo "--- 5. 앱 부트 시퀀스 / 리슨 ---"
sed -n '/Starting Agent Boot Sequence/,/Agent READY/p' "$AGENT_LOG_DIR/agent_app.console.log" 2>/dev/null | head -20
chk "Boot [OK] 5개"             "[ \$(grep -c '\[OK\]' $AGENT_LOG_DIR/agent_app.console.log) -ge 5 ]"
chk "Agent READY"               "grep -q 'Agent READY' $AGENT_LOG_DIR/agent_app.console.log"
chk "0.0.0.0:15034 LISTEN"      "ss -tln | grep -q '0.0.0.0:$AGENT_PORT'"
chk "앱 실행자가 root 아님"     "[ \"\$(ps -o user= -p \$(pgrep -f /usr/local/bin/agent-app | head -1))\" = $AGENT_ADMIN ]"

echo
echo "--- 6. monitor.sh ---"
stat -c '%n owner=%U group=%G mode=%a' "$AGENT_HOME/bin/monitor.sh" 2>/dev/null
chk "monitor.sh agent-dev:agent-core 750" "[ \"\$(stat -c %U $AGENT_HOME/bin/monitor.sh)\" = $AGENT_DEV ] && [ \"\$(stat -c %G $AGENT_HOME/bin/monitor.sh)\" = $GRP_CORE ] && [ \"\$(stat -c %a $AGENT_HOME/bin/monitor.sh)\" = 750 ]"

echo
echo "--- 7. monitor.log 누적 ---"
echo "라인 수: $(wc -l < "$AGENT_LOG_DIR/monitor.log" 2>/dev/null || echo 0)"
tail -3 "$AGENT_LOG_DIR/monitor.log" 2>/dev/null
chk "monitor.log 포맷"          "grep -Eq '^\[[0-9-]{10} [0-9:]{8}\] PID:[0-9]+ CPU:[0-9.]+% MEM:[0-9.]+% DISK_USED:[0-9]+%' $AGENT_LOG_DIR/monitor.log"

echo
echo "--- 8. 주기 실행 (cron) ---"
if pgrep -x crond >/dev/null 2>&1 || pgrep -x cron >/dev/null 2>&1; then
  echo "크론 데몬: $( (pgrep -a cron; pgrep -a crond) 2>/dev/null | head -1)"
  echo "agent-admin crontab:"; crontab -l -u "$AGENT_ADMIN" 2>/dev/null
  chk "크론 데몬 가동(cron/crond)" "pgrep -x crond >/dev/null || pgrep -x cron >/dev/null"
  chk "agent-admin crontab 매분 등록" "crontab -l -u $AGENT_ADMIN 2>/dev/null | grep -q '^\* \* \* \* \*.*monitor\.sh'"
  # dcron 은 crontab 파일을 root 소유일 때만 로드한다 (database.c:354 st_uid == DaemonUid)
  chk "crontab 파일 root 소유/0600" "[ -f /var/spool/cron/crontabs/$AGENT_ADMIN ] && [ \$(stat -c %u /var/spool/cron/crontabs/$AGENT_ADMIN) = 0 ] && [ \$(stat -c %a /var/spool/cron/crontabs/$AGENT_ADMIN) = 600 ]"
else
  echo "(cron 미설치 환경 → 루프 폴백 스케줄러 검사)"
  PIDF="$AGENT_LOG_DIR/scheduler.pid"
  [[ -f $PIDF ]] && ps -o pid,user,etime,cmd -p "$(cat $PIDF)" 2>/dev/null
  echo "scheduler.log:"; tail -3 "$AGENT_LOG_DIR/scheduler.log" 2>/dev/null
  chk "폴백 스케줄러 가동"        "[ -f $PIDF ] && kill -0 \$(cat $PIDF)"
fi

echo
echo "--- 9. POSIX ACL (libacl 직접 호출로 설정) ---"
for d in "$AGENT_UPLOAD_DIR" "$AGENT_KEYS_DIR" "$AGENT_LOG_DIR"; do
  ls -ld "$d"
done
echo "upload_files 기본(상속) ACL:"; python3 "$(dirname "$0")/acltool.py" get "$AGENT_UPLOAD_DIR" --default 2>/dev/null
chk "upload_files 에 ACL 존재(ls +)"   "ls -ld $AGENT_UPLOAD_DIR | grep -q '^d[rwx-]\{9\}+'"
chk "api_keys 에 ACL 존재(ls +)"      "ls -ld $AGENT_KEYS_DIR | grep -q '^d[rwx-]\{9\}+'"
chk "/var/log/agent-app 에 ACL 존재"  "ls -ld $AGENT_LOG_DIR | grep -q '^d[rwx-]\{9\}+'"
chk "ACL: agent-test 는 api_keys 접근 불가" "! runuser -u $AGENT_TEST -- cat $AGENT_KEYS_DIR/secret.key >/dev/null 2>&1"
chk "ACL: agent-test 는 upload_files 쓰기 가능" "runuser -u $AGENT_TEST -- bash -c 'echo t > $AGENT_UPLOAD_DIR/.acl_probe && rm -f $AGENT_UPLOAD_DIR/.acl_probe'"
chk "ACL: agent-dev 는 secret.key 읽기 가능" "runuser -u $AGENT_DEV -- cat $AGENT_KEYS_DIR/secret.key >/dev/null 2>&1"

echo
echo "--- 10. 로그 로테이션(10MB x 10) 실측 ---"
ls -lh "$AGENT_LOG_DIR"/rotation-test.log* 2>/dev/null | awk '{print $5, $9}'
chk "로테이션 실측 로그 존재"      "[ -f $AGENT_LOG_DIR/rotation-test.log ]"
chk "10MB 도달 시 회전 발생(.gz)"  "ls -1 $AGENT_LOG_DIR/rotation-test.log.*.gz >/dev/null 2>&1"
chk "회전본 10개 유지 정책"        "[ \$(ls -1 $AGENT_LOG_DIR/rotation-test.log.*.gz 2>/dev/null | wc -l) -eq 10 ]"
chk "회전본 gzip 무결성"           "gzip -t $AGENT_LOG_DIR/rotation-test.log.*.gz >/dev/null 2>&1"

echo
echo "############ RESULT: PASS=$pass FAIL=$fail ############"
[[ $fail -eq 0 ]] && echo "B1-1 VERIFICATION: ALL PASS" || echo "B1-1 VERIFICATION: $fail FAIL"
