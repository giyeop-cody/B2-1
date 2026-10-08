#!/usr/bin/env bash
# B1-1 [1/6] 계정·그룹·디렉토리·권한·키 파일·환경변수 프로비저닝
# 실행: sudo bash 01-provision.sh
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

echo "== [1/6] 그룹 생성 ($GRP_COMMON, $GRP_CORE) =="
for g in "$GRP_COMMON" "$GRP_CORE"; do
  getent group "$g" >/dev/null || groupadd "$g"
  getent group "$g"
done

echo
echo "== [2/6] 계정 생성 ($AGENT_ADMIN, $AGENT_DEV, $AGENT_TEST) =="
for u in "$AGENT_ADMIN" "$AGENT_DEV" "$AGENT_TEST"; do
  id -u "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
  id "$u"
done

echo
echo "== [3/6] 그룹 소속 (agent-common: admin/dev/test · agent-core: admin/dev) =="
usermod -aG "$GRP_COMMON" "$AGENT_ADMIN"
usermod -aG "$GRP_CORE"   "$AGENT_ADMIN"   # cron 실행자 agent-admin 은 monitor.sh(750, agent-core) 를 실행해야 한다
usermod -aG "$GRP_COMMON,$GRP_CORE" "$AGENT_DEV"
usermod -aG "$GRP_COMMON" "$AGENT_TEST"
for u in "$AGENT_ADMIN" "$AGENT_DEV" "$AGENT_TEST"; do id "$u"; done
echo "--- 그룹 원장 (getent group) ---"
getent group "$GRP_COMMON" "$GRP_CORE"

echo
echo "== [4/6] 디렉토리 구조 ($AGENT_HOME 기준) =="
install -d -o "$AGENT_ADMIN" -g "$GRP_COMMON" -m 750 "$AGENT_HOME"
install -d -o "$AGENT_ADMIN" -g "$GRP_COMMON" -m 770 "$AGENT_UPLOAD_DIR"
install -d -o "$AGENT_ADMIN" -g "$GRP_CORE"   -m 770 "$AGENT_KEYS_DIR"
install -d -o "$AGENT_DEV"   -g "$GRP_CORE"   -m 750 "$AGENT_HOME/bin"
install -d -o "$AGENT_ADMIN" -g "$GRP_CORE"   -m 770 "$AGENT_LOG_DIR"
ls -ld "$AGENT_HOME" "$AGENT_UPLOAD_DIR" "$AGENT_KEYS_DIR" "$AGENT_HOME/bin" "$AGENT_LOG_DIR"

echo
echo "== [5/6] 키 파일 생성 =="
# 미션 원문(B1-1)은 $AGENT_HOME/api_keys/t_secret.key 를 요구한다.
# 제공 바이너리 부트시퀀스 [3/5]는 AGENT_KEY_PATH 디렉토리 안의 'secret.key' 를 실제로 검증한다
# (AGENT_KEY_PATH 를 .../t_secret.key 로 주면 "Key Path Mismatch" 로 부트 실패 — 실측 확인).
# 따라서 미션 원문 파일(t_secret.key)과 앱이 요구하는 파일(secret.key)을 같은 내용으로 함께 둔다.
printf 'agent_api_key_test\n' > "$AGENT_KEYS_DIR/t_secret.key"
cp -a "$AGENT_KEYS_DIR/t_secret.key" "$AGENT_KEYS_DIR/secret.key"
chown "$AGENT_ADMIN:$GRP_CORE" "$AGENT_KEYS_DIR"/*.key
chmod 640 "$AGENT_KEYS_DIR"/*.key
ls -l "$AGENT_KEYS_DIR"

echo
echo "== [6/6] 실행 환경 고정 (env.sh + .bash_profile) =="
cat > "$AGENT_HOME/env.sh" <<EOF
# B1-1/B1-2 agent 앱 실행 환경 (source 해서 사용)
export AGENT_HOME="$AGENT_HOME"
export AGENT_PORT=$AGENT_PORT
export AGENT_UPLOAD_DIR="$AGENT_UPLOAD_DIR"
export AGENT_KEY_PATH="$AGENT_KEYS_DIR"
export AGENT_LOG_DIR="$AGENT_LOG_DIR"
# B1-2 시나리오 변수 (기본값: 정상 운영)
export MEMORY_LIMIT="\${MEMORY_LIMIT:-256}"
export CPU_MAX_OCCUPY="\${CPU_MAX_OCCUPY:-50}"
export MULTI_THREAD_ENABLE="\${MULTI_THREAD_ENABLE:-false}"
EOF
chown "$AGENT_ADMIN:$GRP_COMMON" "$AGENT_HOME/env.sh"
chmod 640 "$AGENT_HOME/env.sh"
grep -q 'agent-app/env.sh' "/home/$AGENT_ADMIN/.bash_profile" 2>/dev/null || \
  echo "[ -f \"$AGENT_HOME/env.sh\" ] && . \"$AGENT_HOME/env.sh\"" >> "/home/$AGENT_ADMIN/.bash_profile"
chown "$AGENT_ADMIN:$AGENT_ADMIN" "/home/$AGENT_ADMIN/.bash_profile"
cat "$AGENT_HOME/env.sh"

echo
echo "== PROVISION DONE =="
