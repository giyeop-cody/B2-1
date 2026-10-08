#!/usr/bin/env bash
# B1-1 [추가] 로그 로테이션 실측 — 10MB 도달 시 회전 + 10개 유지 + gzip 을 실제로 발생시킨다
# 실행: sudo bash 08-logrotate-test.sh [회전횟수:기본 12]
#
# 이전 상태: monitor.log 이 수십 줄(수 KB) 뿐이라 "10MB x 10" 정책이 **한 번도 발동한 적이 없었다**
# (README 한계 항목에 '미실시'로 기재). 이 스크립트는 그 정책을 실제로 발동시켜 실측한다.
#
# 방법: monitor.sh 의 **rotate_logs() 를 그대로 실행**한다. 단, 실 운영 로그(monitor.log)를
# 10MB 로 부풀려 깨뜨리지 않도록 LOG_FILE 경로만 교체한 사본을 만들어 돌린다
# (로직은 사본이 아니라 원본 monitor.sh 의 함수 그 자체).
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

TEST_LOG="$AGENT_LOG_DIR/rotation-test.log"
TEST_SH="$AGENT_HOME/bin/monitor-rotation-test.sh"
ROUNDS=${1:-12}   # 10개 유지 정책 확인을 위해 10회보다 많이 회전시킨다

echo "== [1/4] 대상 로그 파일만 교체한 monitor.sh 사본 생성 (rotate_logs 원본 사용) =="
sed "s@^LOG_FILE=.*@LOG_FILE=\"$TEST_LOG\"@" "$(dirname "$0")/monitor.sh" > "$TEST_SH"
chmod 750 "$TEST_SH"; chown "$AGENT_DEV":"$GRP_CORE" "$TEST_SH"
grep -n '^LOG_FILE=\|^MAX_LOG_SIZE=\|^MAX_LOG_FILES=' "$TEST_SH"

echo
echo "== [2/4] 정리 후 $ROUNDS 회 회전 발생시키기 =="
rm -f "$TEST_LOG" "$TEST_LOG".*.gz
LINE='[2026-10-06 22:00:00] PID:3300 CPU:1.00% MEM:1.00% DISK_USED:10%'
for i in $(seq 1 "$ROUNDS"); do
  # 10MB 를 넘는 진짜 로그 라인으로 채운다 (truncate 로 0 바이트 뻥튀기하지 않음)
  # set -o pipefail 이면 head 가 파이프를 닫으면서 yes 가 SIGPIPE(141) 로 죽어 스크립트가 중단된다
  ( set +o pipefail; yes "$LINE" | head -c 10485761 > "$TEST_LOG" ) || true
  SIZE_MB=$(awk -v s="$(stat -c%s "$TEST_LOG")" 'BEGIN{printf "%.1f", s/1048576}')
  runuser -u "$AGENT_ADMIN" -- "$TEST_SH" >/dev/null 2>&1 || true
  sleep 1   # 회전 파일명이 초 단위이므로 서로 다른 이름을 위해 1초 대기
  printf '  round %-2s : 직전 크기 %sMB → 회전 후 원본 %s, 회전본 누적 %s개\n' \
    "$i" "$SIZE_MB" "$(stat -c%s "$TEST_LOG" 2>/dev/null || echo 없음)" \
    "$(ls -1 "$TEST_LOG".*.gz 2>/dev/null | wc -l)"
done

echo
echo "== [3/4] 결과 파일 목록 =="
ls -lh "$TEST_LOG" "$TEST_LOG".*.gz 2>/dev/null | awk '{print $5, $9}'
echo "총 회전본 개수: $(ls -1 "$TEST_LOG".*.gz 2>/dev/null | wc -l) (정책: 최대 10개 유지)"
echo "총 사용량    : $(du -ch "$TEST_LOG" "$TEST_LOG".*.gz 2>/dev/null | tail -1 | cut -f1)"

echo
echo "== [4/4] 판정 =="
CNT=$(ls -1 "$TEST_LOG".*.gz 2>/dev/null | wc -l)
[[ $CNT -eq 10 ]] && echo "[PASS] 회전본 10개 유지 (초과분 삭제 확인: $ROUNDS 회 회전했으나 10개)" \
                  || echo "[FAIL] 회전본 개수 $CNT (기대 10)"
if gzip -t "$TEST_LOG".*.gz >/dev/null 2>&1; then
  echo "[PASS] 회전본 전부 정상 gzip"
  echo "       회전본 크기 예시: $(ls -lh "$TEST_LOG".*.gz 2>/dev/null | head -1 | awk '{print $5}') (원본 10MB)"
else
  echo "[FAIL] gzip 무결성 검사 실패"
fi
if [[ $(stat -c%s "$TEST_LOG") -lt 10485760 ]]; then
  echo "[PASS] 회전 후 원본 로그는 새로 시작 ($(stat -c%s "$TEST_LOG") bytes < 10MB)"
else
  echo "[FAIL] 회전 후에도 원본이 10MB 이상"
fi
rm -f "$TEST_SH"
echo "== ROTATION TEST DONE =="
