#!/usr/bin/env bash
# B1-1 lab [0b/6] 진짜 cron 데몬 설치 — apt 가 막힌 환경에서 소스로 빌드
# 실행: sudo bash 00b-build-cron.sh
#
# 배경(실측): 이 샌드박스는 Debian 저장소에 접속하지 못한다.
#   apt-get update → deb.debian.org Connection failed · apt-cache policy cron → Candidate: none
#   curl https://deb.debian.org|security.debian.org|archive.ubuntu.org|ftp.kr.debian.org → 000
# 하지만 **github.com 은 열린다**(curl -I https://github.com → 200) 그리고 gcc/make 가 있다.
#   → cron 구현체인 dcron(Dillon's cron, 4.5)을 소스에서 빌드해 설치한다.
#   dcron 은 autotools 없이 순수 Makefile 로 빌드되는 실제 cron 데몬이다(래퍼가 아님).
# 결과: /usr/local/sbin/crond + /usr/local/bin/crontab(setgid crontab) + /var/spool/cron/crontabs
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

# 크론 데몬 프로세스명은 배포판마다 다르다: Ubuntu/Debian 패키지 cron 은 **cron**,
# 소스 빌드한 dcron 은 **crond**. 둘 다 인정한다.
cron_running() { pgrep -x crond >/dev/null 2>&1 || pgrep -x cron >/dev/null 2>&1; }
if command -v crontab >/dev/null 2>&1 && cron_running; then
  echo "이미 설치·가동 중: $(command -v crontab) · 데몬 pid=$(pgrep -x cron; pgrep -x crond)"
  exit 0
fi

echo "== [1/5] 저장소 접속 실측 (왜 소스 빌드인가) =="
for u in https://deb.debian.org https://archive.ubuntu.org https://github.com; do
  printf '  %-30s ' "$u"; curl -sS -o /dev/null -m 8 -w '%{http_code}\n' "$u" 2>/dev/null || echo "접속 실패"
done
echo "  gcc: $(command -v gcc) · make: $(command -v make)"

BUILD="${BUILD_DIR:-/usr/src/b1-build}"
echo
echo "== [2/5] dcron 소스 클론 =="
mkdir -p "$BUILD"; cd "$BUILD"
[[ -d dcron ]] || git clone --depth 1 https://github.com/dubiousjim/dcron.git
cd dcron
grep -m1 '^VERSION' Makefile

echo
echo "== [3/5] 빌드 (CRONTAB_GROUP=crontab) =="
getent group crontab >/dev/null || groupadd crontab
make CRONTAB_GROUP=crontab 2>&1 | tail -3

echo
echo "== [4/5] 설치 =="
make install CRONTAB_GROUP=crontab PREFIX=/usr/local 2>&1 | tail -4
# dcron 의 crontab 은 4750(root:crontab) 으로 깔린다 → 일반 사용자가 자기 crontab 을 못 쓴다.
# Debian 의 crontab 과 동일하게 4755 로 맞춰준다(소유/권한 검사는 crontab 이 자체 수행).
chmod 4755 /usr/local/bin/crontab
ls -l /usr/local/bin/crontab /usr/local/sbin/crond
ls -ld /var/spool/cron/crontabs /var/spool/cron/cronstamps /etc/cron.d

echo
echo "== [5/5] crond 를 systemd 서비스로 등록·기동 =="
if systemctl is-system-running >/dev/null 2>&1 || [[ -S /run/systemd/private ]]; then
  # systemd 단위 작성 — 3가지 시도를 실측으로 거쳐 확정했다:
  #  ① Type=forking + PIDFile=/run/crond.pid → dcron 은 pid 파일을 쓰지 않아
  #     "Can't open PID file /run/crond.pid (yet?) after start" + "start operation timed out" 실패.
  #  ② Type=simple + ExecStart ...(-b 없음) → dcron 의 기본값이 -b(백그라운드)라 부모가 즉시 빠져
  #     1ms 만에 "Deactivated successfully" 처리됨.
  #  ③ Type=simple + -f(포그라운드) → dcron 이 setpgid 를 부르는데 이 컨테이너에서
  #     "setpgid: Operation not permitted" 로 status=1 종료.
  #  → 확정안: Type=forking + -b + PIDFile 없음(systemd 가 cgroup 으로 메인 PID 를 잡는다).
  cat > /etc/systemd/system/crond.service <<'UNIT'
[Unit]
Description=Dillon's cron daemon (dcron, built from source)
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/sbin/crond -b -S -L /var/log/crond.log
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload 2>/dev/null || true
  systemctl enable crond 2>&1 | tail -2 || true
  systemctl restart crond 2>&1 | tail -2 || true
  sleep 1
  echo "systemctl is-active crond : $(systemctl is-active crond 2>&1)"
  echo "systemctl is-enabled crond: $(systemctl is-enabled crond 2>&1)"
else
  echo "systemd 버스 없음 → 백그라운드로 직접 기동"
  /usr/local/sbin/crond -b -S -L /var/log/crond.log
fi

for _ in $(seq 1 10); do pgrep -x crond >/dev/null && break; sleep 1; done
echo "crond: $(pgrep -a crond || echo '가동 실패')"
/usr/local/sbin/crond -h 2>&1 | head -1 || true
pgrep -x crond >/dev/null || { echo "!! crond 가동 실패"; exit 1; }
echo "== BUILD CRON DONE =="
