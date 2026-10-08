#!/usr/bin/env bash
# B1-1 lab [0c/6] 진짜 ufw 설치 — apt 가 막힌 환경에서 소스로 설치
# 실행: sudo bash 00c-build-ufw.sh
#
# 배경(실측): apt 저장소 접속 불가 → `apt-cache policy ufw` = Candidate: none, ufw 바이너리 없음.
#   curl https://deb.debian.org|security.debian.org|archive.ubuntu.org|mirror.kakao.com → 000
#   git.savannah.nongnu.org / launchpad.net(ufw 공식 홈) / salsa.debian.org → 000
#   github.com 은 열려 있음(200) → GitHub 에 올라온 ufw **소스 트리**를 받아 설치한다.
#
# 출처와 안전성:
#   저장소  https://github.com/rinodung/ufw-uncomplicated-firewall (ufw 0.34 소스 트리)
#   검증    ① src/ 모듈 + conf/ + doc/ufw.8 + examples/ + locales/ = upstream 레이아웃 그대로
#           ② GPL v3 헤더·AUTHORS·ChangeLog 보유
#           ③ 외부 통신/난독화 코드 탐색: grep -rE 'urllib|requests|curl|wget|base64|eval\(|exec\(' src/
#              → socket.getservbyname/inet_pton/has_ipv6 만 해당(로컬 /etc/services 조회용). 그 외 없음.
#   한계    공식 Launchpad 와 바이트 단위 대조는 불가능(launchpad.net 접속 불가) → 아래 [2/4] 에서
#           설치 직전 동일 grep 을 다시 실행해 결과를 로그에 남긴다.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

if command -v ufw >/dev/null 2>&1 && [[ -x /usr/sbin/ufw ]]; then
  echo "이미 설치됨: $(command -v ufw) → $(ufw version 2>&1 | head -1)"
  exit 0
fi

BUILD="${BUILD_DIR:-/usr/src/b1-build}"
echo "== [1/4] 저장소 접속 실측 =="
for u in https://deb.debian.org https://launchpad.net https://github.com; do
  printf '  %-28s ' "$u"; curl -sS -o /dev/null -m 8 -w '%{http_code}\n' "$u" 2>/dev/null || echo "접속 실패"
done

echo
echo "== [2/4] ufw 소스 클론 + 안전 점검 =="
mkdir -p "$BUILD"; cd "$BUILD"
[[ -d ufw ]] || git clone --depth 1 https://github.com/rinodung/ufw-uncomplicated-firewall.git ufw
cd ufw
grep -n "^ufw_version" setup.py
echo "  src/: $(ls src/*.py src/ufw src/ufw-init* 2>/dev/null | wc -l) 개 파일, conf/: $(ls conf | wc -l) 개"
echo "  외부 통신/난독화 탐색:"
if grep -rnE 'urllib|requests\.|curl |wget |base64|eval\(|exec\(' src/*.py src/ufw src/ufw-init src/ufw-init-functions 2>/dev/null; then
  echo "  !! 위 항목을 사람이 확인한 뒤 진행하세요"; exit 1
else
  echo "    (없음 — socket.getservbyname/inet_pton 등 로컬 조회만 사용)"
fi

echo
echo "== [3/4] 설치 (setup.py install) =="
# gettext(msgfmt) 가 없어 번역(.mo)을 만들 수 없다 → 빈 locales/mo 로 건너뛴다(기능과 무관).
#   이것 때문에 setup.py 가 "error: No such file or directory: 'locales/mo'" 로 중단된다(실측).
mkdir -p locales/mo
python3 setup.py install --root=/ --prefix=/usr 2>&1 | tail -4
# setup.py 는 /usr/sbin/ufw 를 0644 로 남긴다 → 실행 권한을 직접 부여해야 한다(실측 발견).
chmod 755 /usr/sbin/ufw /lib/ufw/ufw-init /lib/ufw/ufw-init-functions
ls -l /usr/sbin/ufw /lib/ufw/ufw-init-functions

# 이 커널은 ip6tables 확장(rt/hl)과 xt_LOG/xt_limit 모듈이 없다(실측 경고).
# IPv6 토글은 ufw.conf 가 아니라 **/etc/default/ufw** 에 있다
# (ufw-init-functions:23 이 두 파일을 source 하고 135행에서 $IPV6=yes 를 판정 — 실측).
if grep -q '^IPV6=' /etc/default/ufw 2>/dev/null; then
  sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
else
  echo 'IPV6=no' >> /etc/default/ufw
fi
echo "IPV6 설정: $(grep '^IPV6' /etc/default/ufw)"

echo
echo "== [4/4] 동작 확인 =="
/usr/sbin/ufw version
/usr/sbin/ufw status
echo "== BUILD UFW DONE =="
