#!/usr/bin/env bash
# B1-1 lab — 처음부터 끝까지 한 번에 (샌드박스 초기화 후 재현용 / 클라우드 VM 최초 셋업용)
# 실행: sudo bash run-all.sh          (약 4분: 검증 + 로테이션 실측 + 125초 자동누적 대기 포함)
#       sudo bash run-all.sh --quick  (자동누적 대기 생략)
set -uo pipefail
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }
cd "$(dirname "$0")"
QUICK="${1:-}"

echo "########## [0/10] 바이너리 준비 ##########"
bash 00-bootstrap.sh || { echo "부트스트랩 실패 — 네트워크/저장소 확인"; exit 1; }

echo
echo "########## [1a/10] cron 데몬 준비 (apt 불가 → dcron 소스 빌드) ##########"
# 실패해도 중단하지 않는다 — 06-scheduler.sh 가 루프 폴백으로 계속 진행하며 그 사실을 라벨링한다.
bash 00b-build-cron.sh || echo "!! cron 설치 실패 → 06-scheduler.sh 가 폴백 모드로 진행"

echo
echo "########## [1b/10] 방화벽 도구 준비 (apt 불가 → ufw 소스 설치) ##########"
# 실패해도 중단하지 않는다 — 03-firewall.sh 가 iptables 폴백으로 계속 진행하며 그 사실을 라벨링한다.
bash 00c-build-ufw.sh || echo "!! ufw 설치 실패 → 03-firewall.sh 가 iptables 폴백으로 진행"

for s in 01-provision 01b-acl 02-ssh-hardening 03-firewall 04-app-run 05-monitor-install 06-scheduler; do
  echo
  echo "########## $s ##########"
  bash "$s.sh" || { echo "!! $s 실패 — 중단"; exit 1; }
done

echo
echo "########## [8/10] 로그 로테이션(10MB x 10) 실측 ##########"
bash 08-logrotate-test.sh || echo "!! 로테이션 실측 실패"

echo
echo "########## [9/10] 체크리스트 검증 ##########"
bash verify-all.sh

if [[ "$QUICK" != "--quick" ]]; then
  echo
  echo "########## [10/10] 매분 자동 누적 확인 (125초) ##########"
  bash 07-autorun-check.sh
fi

echo
echo "########## ALL DONE ##########"
echo "B1-2 로 이어서 가려면: sudo bash ../../../B1-2/lab/scripts/10-deploy-leak-app.sh"
