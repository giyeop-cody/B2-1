#!/usr/bin/env bash
# B1-1 [2/6] SSH 포트 20022 변경 + Root 원격 로그인 차단
# 실행: sudo bash 02-ssh-hardening.sh
#
# 참고: 이 샌드박스는 systemd PID1 이지만 D-Bus 버스가 없어 systemctl 을 쓸 수 없다
#       ("Failed to connect to bus"). 그래서 sshd 는 설정 검증 후 직접 재기동한다.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

echo "== [1/4] 하드닝 설정 드롭인 작성: $SSH_DROPIN =="
mkdir -p /etc/ssh/sshd_config.d
cat > "$SSH_DROPIN" <<EOF
# B1-1 기본 보안: SSH 포트 변경 + Root 원격 로그인 차단
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
EOF
cat "$SSH_DROPIN"
grep -n 'Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config || true

echo
echo "== [2/4] 호스트 키 보장 + 설정 문법 검증 =="
ssh-keygen -A >/dev/null 2>&1 || true
mkdir -p /run/sshd; chmod 0755 /run/sshd
/usr/sbin/sshd -t && echo "sshd -t: OK (설정 문법 정상)"

echo
echo "== [3/4] sshd 재기동 (기존 인스턴스 종료 → 새 설정으로 기동) =="
OLD_PIDS="$(pgrep -x sshd || true)"
echo "기존 sshd PID: ${OLD_PIDS:-none}"
if [[ -n "$OLD_PIDS" ]]; then kill $OLD_PIDS 2>/dev/null || true; sleep 1; fi
# 특권분리 디렉토리는 sshd 기동 "직전"에 만든다.
# 이 환경에서는 /run/sshd 가 사라지는 경우가 실측됐다: 같은 스크립트 안에서 조금 전에
# `ls -ld /run/sshd` 가 찍혔는데 기동 시점에는 "Missing privilege separation directory" 로 실패했다.
ensure_privsep() { mkdir -p /run/sshd; chown root:root /run/sshd; chmod 0755 /run/sshd; }
ensure_privsep
ls -ld /run/sshd
/usr/sbin/sshd || { echo "1차 기동 실패 → privsep 재생성 후 재시도"; ensure_privsep; /usr/sbin/sshd; }
sleep 1
echo "신규 sshd PID: $(pgrep -x sshd | tr '\n' ' ')"
ss -tln | grep -q ":$SSH_PORT" && echo "sshd 리슨 확인: :$SSH_PORT" || { echo "sshd 가 $SSH_PORT 에서 리슨하지 않음"; exit 1; }

echo
echo "== [4/4] 검증 =="
echo "--- 실효 설정 (sshd -T) ---"
/usr/sbin/sshd -T 2>/dev/null | grep -Ei '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication) '
echo "--- 포트 리슨 (ss -tulnp) ---"
ss -tulnp | grep -E 'sshd|:22 |:22$' || echo "(sshd 라인 없음)"
echo "--- 참고: :22 잔여 리스너 ---"
echo "  ss 출력의 '*:22' 는 프로세스가 systemd(PID 1) 로 찍힌다 = ssh.socket 소켓액티베이션 리스너이며"
echo "  우리가 기동한 sshd 가 아니다. 이 환경은 D-Bus 버스가 없어 'systemctl disable --now ssh.socket'"
echo "  을 실행할 수 없고(systemctl → Failed to connect to bus), PID1 의 fd 를 닫을 방법도 없다."
echo "  우리가 기동한 sshd 는 20022 에서만 리슨한다. 실서비스 VM 에서는 ssh.socket 을 꺼서 :22 를 없앤다."

echo
echo "== [추가] 실제 접속 테스트 (일반 계정 성공 / root 차단) =="
KEY=/home/"$AGENT_ADMIN"/.ssh/id_ed25519
install -d -m 700 -o "$AGENT_ADMIN" -g "$AGENT_ADMIN" /home/"$AGENT_ADMIN"/.ssh
[[ -f "$KEY" ]] || ssh-keygen -t ed25519 -N '' -f "$KEY" -C "$AGENT_ADMIN@b1-lab" >/dev/null
cp -f "$KEY.pub" /home/"$AGENT_ADMIN"/.ssh/authorized_keys
chown -R "$AGENT_ADMIN:$AGENT_ADMIN" /home/"$AGENT_ADMIN"/.ssh
chmod 700 /home/"$AGENT_ADMIN"/.ssh
chmod 600 "$KEY" /home/"$AGENT_ADMIN"/.ssh/authorized_keys
ls -l /home/"$AGENT_ADMIN"/.ssh
SSHOPT="-p $SSH_PORT -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5"
echo "--- agent-admin 접속 ---"
runuser -u "$AGENT_ADMIN" -- ssh $SSHOPT "$AGENT_ADMIN"@127.0.0.1 'id; hostname; echo LOGIN_OK' 2>&1 | grep -v 'Warning: Permanently added'
echo "--- root 접속 시도 (차단돼야 정상 → 실패 종료코드는 의도된 것) ---"
# set -o pipefail 때문에 ssh 의 255 가 스크립트 전체 실패로 전파된다. 여기서 실패가 곧 정상이므로 삼킨다.
{ runuser -u "$AGENT_ADMIN" -- ssh $SSHOPT root@127.0.0.1 'id' 2>&1 | grep -v 'Warning: Permanently added' | tail -2; } || true
echo
echo "== SSH HARDENING DONE =="
