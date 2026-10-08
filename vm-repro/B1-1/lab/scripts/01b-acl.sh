#!/usr/bin/env bash
# B1-1 [1b/6] 실제 POSIX ACL 적용 — "ACL→모드 비트" 대체를 걷어낸 버전
# 실행: sudo bash 01b-acl.sh
#
# 이 샌드박스에는 setfacl/getfacl 이 없다(acl 패키지 설치 불가). 하지만 **libacl.so.1 은 설치돼 있다**
# (dpkg -l | grep libacl1 → 2.3.1-3). acltool.py 가 그 라이브러리를 ctypes 로 직접 호출하므로
# 파일시스템에 남는 ACL 은 setfacl 이 만든 것과 동일한 진짜 POSIX ACL 이다.
# 독립 검증: ① GNU ls 의 '+' 표시 ② 실제 계정으로 접근 테스트 ③ 신규 파일 권한 상속 확인
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }
ACLTOOL="$(dirname "$0")/acltool.py"

echo "== [0/4] 환경 실측 =="
echo -n "setfacl: "; command -v setfacl || echo "MISSING"
echo -n "getfacl: "; command -v getfacl || echo "MISSING"
echo "libacl : $(ls -l /lib/x86_64-linux-gnu/libacl.so.1 2>/dev/null | awk '{print $NF}')"
dpkg -l 2>/dev/null | grep -E '^ii +libacl1' || true

echo
echo "== [1/4] 접근 ACL + 기본(상속) ACL 적용 =="
# Ubuntu useradd creates a 0750 home. Allow the shared group to traverse it
# without granting access to unrelated personal files or directory listings.
python3 "$ACLTOOL" set "/home/$AGENT_ADMIN" "u::rwx,g::r-x,g:$GRP_COMMON:--x,o::---"
# 정책: upload_files = agent-common RW · api_keys = agent-core 전용 · /var/log/agent-app = agent-core 전용
# 기본 ACL(default) 을 함께 거는 이유: umask 022 에서 새로 만든 파일은 그룹 쓰기 권한이 사라진다.
# 기본 ACL 이 있으면 디렉토리 안의 신규 파일이 그룹 RW 를 **상속**한다 (아래 [3/4] 에서 실증).
python3 "$ACLTOOL" set "$AGENT_UPLOAD_DIR" "u::rwx,g::rwx,g:$GRP_COMMON:rwx,o::---"
python3 "$ACLTOOL" set "$AGENT_UPLOAD_DIR" "u::rwx,g::rwx,g:$GRP_COMMON:rwx,o::---" --default
python3 "$ACLTOOL" set "$AGENT_KEYS_DIR"   "u::rwx,g::rwx,g:$GRP_CORE:rwx,o::---"
python3 "$ACLTOOL" set "$AGENT_KEYS_DIR"   "u::rwx,g::rwx,g:$GRP_CORE:rwx,o::---" --default
python3 "$ACLTOOL" set "$AGENT_LOG_DIR"    "u::rwx,g::rwx,g:$GRP_CORE:rwx,o::---"
python3 "$ACLTOOL" set "$AGENT_LOG_DIR"    "u::rwx,g::rwx,g:$GRP_CORE:rwx,o::---" --default

echo
echo "== [2/4] 독립 검증 ① — GNU ls 의 '+' 표시 (ACL 이 모드비트와別に 존재한다는 뜻) =="
ls -ld "$AGENT_UPLOAD_DIR" "$AGENT_KEYS_DIR" "$AGENT_LOG_DIR"
echo "-- 읽기 검증: $AGENT_KEYS_DIR 기본 ACL --"
python3 "$ACLTOOL" get "$AGENT_KEYS_DIR" --default

echo
echo "== [3/4] 독립 검증 ② — 신규 파일 권한 상속 (umask 022 상태) =="
rm -f "$AGENT_UPLOAD_DIR"/acl_inherit_test.txt
runuser -u "$AGENT_DEV" -- bash -c "umask 022; echo hi > '$AGENT_UPLOAD_DIR/acl_inherit_test.txt'"
ls -l "$AGENT_UPLOAD_DIR/acl_inherit_test.txt"
PERM="$(stat -c %A "$AGENT_UPLOAD_DIR/acl_inherit_test.txt")"
if [[ "$PERM" == -rw-rw-* ]]; then
  echo "[PASS] 그룹 쓰기 상속됨 ($PERM) — umask 022 만으로는 -rw-r--r-- 가 됐을 것"
else
  echo "[FAIL] 그룹 쓰기 없음 ($PERM)"
fi
echo "-- 상속된 ACL (소유 그룹이 agent-dev 인데도 agent-common 항목이 붙어 있다) --"
python3 "$ACLTOOL" get "$AGENT_UPLOAD_DIR/acl_inherit_test.txt"
echo "-- 대조군: 기본 ACL 없는 디렉토리에서 같은 작업 --"
rm -rf /tmp/acl-control && install -d -o "$AGENT_ADMIN" -g "$GRP_COMMON" -m 770 /tmp/acl-control
runuser -u "$AGENT_DEV" -- bash -c "umask 022; echo hi > /tmp/acl-control/no_acl.txt"
stat -c '%A %U:%G %n' /tmp/acl-control/no_acl.txt
rm -rf /tmp/acl-control

echo
echo "== [4/4] 독립 검증 ③ — 실제 계정 접근 테스트 =="
echo "--- agent-test(agent-common 만) 가 upload_files 에 쓰기 → 성공해야 정상 ---"
if runuser -u "$AGENT_TEST" -- bash -c "echo by-test > '$AGENT_UPLOAD_DIR/by_agent_test.txt'" 2>&1; then
  echo "[PASS] agent-test 쓰기 성공"; ls -l "$AGENT_UPLOAD_DIR/by_agent_test.txt"
else
  echo "[FAIL] agent-test 쓰기 실패"
fi
echo "--- agent-test 가 api_keys/secret.key 읽기 → 실패해야 정상 (agent-core 전용) ---"
if runuser -u "$AGENT_TEST" -- cat "$AGENT_KEYS_DIR/secret.key" >/dev/null 2>&1; then
  echo "[FAIL] agent-test 가 secret.key 를 읽었다 — 정책 위반"
else
  echo "[PASS] agent-test 접근 거부 (agent-core 전용 정책 유지)"
fi
echo "--- agent-dev(agent-core) 가 secret.key 읽기 → 성공해야 정상 ---"
if runuser -u "$AGENT_DEV" -- cat "$AGENT_KEYS_DIR/secret.key" >/dev/null 2>&1; then
  echo "[PASS] agent-dev 읽기 성공"
else
  echo "[FAIL] agent-dev 읽기 실패"
fi
echo "--- agent-test 가 /var/log/agent-app 목록 보기 → 실패해야 정상 ---"
if runuser -u "$AGENT_TEST" -- ls "$AGENT_LOG_DIR" >/dev/null 2>&1; then
  echo "[FAIL] agent-test 가 로그 디렉토리를 봤다"
else
  echo "[PASS] agent-test 로그 디렉토리 접근 거부"
fi

rm -f "$AGENT_UPLOAD_DIR/acl_inherit_test.txt" "$AGENT_UPLOAD_DIR/by_agent_test.txt"
echo
echo "== ACL DONE =="
