#!/usr/bin/env bash
# B1-1 [3/6] 방화벽 — 실제 ufw 로 인바운드 TCP 20022(SSH) · 15034(APP) 만 허용
# 실행: sudo bash 03-firewall.sh
#
# 과거 이 샌드박스에는 ufw 가 없어 iptables 로 **대체**했었다(라벨링된 우회).
# 지금은 00c-build-ufw.sh 로 ufw 0.34 를 소스에서 설치하므로 **미션 그대로 ufw 를 사용**한다.
# ufw 가 끝내 없는 환경에서만 맨 아래 iptables 폴백을 사용한다.
#
# ★ 안전장치(dead-man's switch) — 실제로 사고를 겪고 추가했다:
#   ufw --force enable 이 중간에 실패하면(이 커널은 modprobe/xt_LOG/ip6tables 확장이 없어
#   "ERROR: problem running ufw-init" 가 난다) 규칙이 **반쯤 적용된 채** INPUT 이 DROP 으로 남아
#   원격 세션이 완전히 끊긴다. 그래서 enable 전에 "45초 후 자동으로 방화벽을 걷어내는"
#   워치독을 걸고, enable + 검증이 성공했을 때만 그 워치독을 해제한다.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

# 이 샌드박스의 제어 채널(envd) 예외. 실제 VM/클라우드에서는 **빈 값**으로 실행해
# 미션 그대로 20022/15034 두 개만 남긴다:  sudo CONTROL_PORT= bash 03-firewall.sh
CONTROL_PORT="${CONTROL_PORT-49983}"

rollback() {
  echo "!! 롤백 실행: ufw disable + INPUT 정책 ACCEPT 복원"
  command -v ufw >/dev/null 2>&1 && ufw --force disable >/dev/null 2>&1 || true
  iptables -F 2>/dev/null || true
  iptables -X 2>/dev/null || true
  iptables -P INPUT ACCEPT 2>/dev/null || true
  iptables -P FORWARD ACCEPT 2>/dev/null || true
  ip6tables -F 2>/dev/null || true
  ip6tables -P INPUT ACCEPT 2>/dev/null || true
}

echo "== [0/7] 환경 실측 =="
echo -n "ufw: ";         command -v ufw || echo "MISSING"
echo -n "firewall-cmd: "; command -v firewall-cmd || echo "MISSING"
echo "iptables: $(iptables -V)"
echo -n "nft inet family: "; { nft add table inet probe_inet 2>&1 | head -1; } || true
nft delete table inet probe_inet 2>/dev/null || true

if command -v ufw >/dev/null 2>&1; then
  echo
  echo "== [1/7] 이 커널에 맞춘 ufw 설정 (실측 근거) =="
  # ① IPv6 규칙 로딩 실패: ip6tables-restore 가
  #      "Extension rt revision 0 not supported, missing kernel module?"
  #      "Extension hl revision 0 not supported, missing kernel module?" 를 내며
  #      ufw6-before-input 등 체인 생성에 실패한다 → IPV6=no 로 v6 규칙 로딩을 끈다.
  #      (토글 위치는 ufw.conf 가 아니라 **/etc/default/ufw** — 실측: ufw-init-functions:23 이
  #       "/etc/default/ufw" 와 "/etc/ufw/ufw.conf" 를 source 하고 135행에서 $IPV6=yes 를 판정)
  # ② 로깅 규칙 실패: "Extension LOG/limit revision 0 not supported" (xt_LOG/xt_limit 없음) → logging off
  # 두 가지 모두 도구 대체가 아니라 **이 커널의 모듈 부재에 맞춘 설정**이다. 일반 VM 에서는 불필요하다.
  UFW_DEFAULTS=/etc/default/ufw
  if grep -q '^IPV6=' "$UFW_DEFAULTS" 2>/dev/null; then
    sed -i 's/^IPV6=.*/IPV6=no/' "$UFW_DEFAULTS"
  else
    echo 'IPV6=no' >> "$UFW_DEFAULTS"
  fi
  grep -n '^IPV6' "$UFW_DEFAULTS" || true
  ufw logging off 2>/dev/null || true
  echo "ufw 버전: $(ufw version 2>&1 | head -1)"
  ufw status verbose || true

  echo
  echo "== [2/7] 기본 정책: 인바운드 deny / 아웃바운드 allow =="
  ufw default deny incoming
  ufw default allow outgoing

  echo
  echo "== [3/7] 허용 규칙 등록 =="
  # 미션 요구사항: 20022/tcp(SSH), 15034/tcp(APP)
  # 주의: 소스로 설치한 ufw 는 0.34 인데, 규칙 뒤의 "comment '텍스트'" 문법은 0.35 에서 추가됐다.
  #   0.34 에서 붙이면 "ERROR: Wrong number of arguments" 로 거부된다(실측 확인) → 주석 없이 등록하고
  #   각 규칙의 용도는 이 스크립트와 증거 문서에 남긴다.
  echo "  # 20022/tcp = SSH, 15034/tcp = APP"
  [[ -n "$CONTROL_PORT" ]] && echo "  # ${CONTROL_PORT}/tcp = 샌드박스 제어 채널 예외(VM 에서는 CONTROL_PORT= 로 비운다)"
  ufw allow "$SSH_PORT"/tcp
  ufw allow "$AGENT_PORT"/tcp
  [[ -n "$CONTROL_PORT" ]] && ufw allow "$CONTROL_PORT"/tcp
  ufw show added

  echo
  echo "== [4/7] enable 전 안전 점검: 제어 채널 허용 규칙이 정말 들어갔는가 =="
  # 'ufw status numbered' 는 ufw 가 inactive 일 때 아무것도 출력하지 않는다(실측) →
  # 활성 여부와 무관하게 보이는 'ufw show added'(= /etc/ufw/user.rules) 로 확인한다.
  if ! ufw show added 2>/dev/null | grep -q "allow $SSH_PORT/tcp"; then
    echo "!! ${SSH_PORT}(SSH) 허용 규칙이 없어 enable 을 중단한다 — 그대로 enable 하면 SSH 가 끊긴다"
    rollback; exit 1
  fi
  echo "  확인됨: $(ufw show added | grep "/tcp" | tr "\n" ' ')"

  echo
  echo "== [5/7] dead-man's switch 설치 후 enable =="
  # 45초 안에 해제되지 않으면 자동으로 방화벽을 걷어낸다(setsid 로 띄워 스크립트가 죽어도 동작하게).
  # 해제 방식은 **취소 파일**이다. setsid 가 자식을 fork 하기 때문에 $! 로는 실제 워치독을 잡지 못한다.
  # 실제로 지난 실행에서 `kill $WATCHDOG` 이 이미 종료된 부모만 죽여서, 45초 뒤 ufw 가 저절로
  # 꺼지는 사고가 있었다(verify-all 이 'Status: inactive' 를 본 원인) → 취소 파일로 확실히 멈춘다.
  CANCEL="/tmp/ufw-enable-ok.$$"
  rm -f "$CANCEL"
  setsid bash -c "
    for _i in \$(seq 1 45); do [ -e '$CANCEL' ] && exit 0; sleep 1; done
    ufw --force disable >/dev/null 2>&1
    iptables -F; iptables -X; iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT
    ip6tables -F 2>/dev/null; ip6tables -P INPUT ACCEPT 2>/dev/null
  " >/dev/null 2>&1 &
  echo "  watchdog 설치 (45초 후 자동 롤백 예정 · 취소 파일=$CANCEL)"
  set +e
  ufw --force enable 2>&1 | tail -6
  UFW_RC=${PIPESTATUS[0]}
  set -e
  if [[ $UFW_RC -ne 0 ]]; then
    echo "!! ufw enable 실패(rc=$UFW_RC) — 롤백한다"
    touch "$CANCEL"   # 워치독 취소(롤백은 아래 rollback 이 수행)
    rollback
    echo "== FIREWALL FAILED (ufw enable 실패, 롤백 완료) =="
    exit 1
  fi

  echo
  echo "== [6/7] 결과 확인 =="
  ufw status verbose
  ufw status numbered
  echo "--- ufw 가 실제로 걸어둔 iptables 규칙(발췌) ---"
  iptables -S | grep -E 'ufw|^-P' | head -20
  # enable 후에도 정책이 실제로 적용됐는지 한 번 더 확인
  if ! ufw status | grep -q 'Status: active'; then
    echo "!! active 가 아님 — 롤백"; touch "$CANCEL"; rollback; exit 1
  fi
  echo "  검증 통과 → watchdog 취소 파일 생성(자동 롤백 해제)"
  touch "$CANCEL"

  echo
  echo "== [7/7] 허용 포트 접속 실측 (로컬) =="
  for p in "$SSH_PORT" "$AGENT_PORT"; do
    if timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/$p" 2>/dev/null; then
      echo "  tcp/$p -> CONNECT OK"
    else
      echo "  tcp/$p -> connect 실패 (아직 리슨 전일 수 있음)"
    fi
  done
  echo "  (참고) 외부에서의 차단 확인은 두 번째 호스트가 필요해 이 샌드박스에서는 재현 불가."
  echo "        클라우드 VM 에서는 'ufw status verbose' + 외부 nmap -p 22,20022,15034 로 확인한다."
  echo "== FIREWALL DONE (ufw) =="
  exit 0
fi

# ---------------------------------------------------------------------------
# 폴백: ufw 를 설치할 수 없는 환경에서만 사용 (iptables 로 동일 정책 적용)
# ---------------------------------------------------------------------------
echo
echo "!! ufw 없음 → iptables 폴백 적용 (00c-build-ufw.sh 로 ufw 설치 권장)"
iptables -F INPUT
iptables -X 2>/dev/null || true
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport "$SSH_PORT"       -m comment --comment "B1-1 SSH" -j ACCEPT
iptables -A INPUT -p tcp --dport "$AGENT_PORT"     -m comment --comment "B1-1 APP" -j ACCEPT
iptables -A INPUT -p tcp --dport "$CONTROL_PORT"   -m comment --comment "sandbox control channel (envd)" -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -S
iptables -L INPUT -v -n --line-numbers
echo "== FIREWALL DONE (iptables 폴백) =="
