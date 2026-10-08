# B1-1 lab — 공통 환경 상수 (다른 스크립트가 source 한다)
# 실행 환경: Arena 샌드박스(Debian 12 컨테이너, sudo root 가능) 를 "VM" 으로 사용

export AGENT_ADMIN=agent-admin
export AGENT_DEV=agent-dev
export AGENT_TEST=agent-test
export GRP_COMMON=agent-common
export GRP_CORE=agent-core

export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEYS_DIR="$AGENT_HOME/api_keys"
export AGENT_LOG_DIR=/var/log/agent-app

export SSH_PORT=20022
export SSH_DROPIN=/etc/ssh/sshd_config.d/99-agent-hardening.conf

# 제공 앱 원본 위치 (giyeop-cody/B1-1 · giyeop-cody/B1-2 공개 레포에서 클론)
# 샌드박스는 /home/user 밖이 턴마다 초기화되므로 00-bootstrap.sh 가 다시 받아온다.
# 클라우드 VM 에서는 LAB_SRC=/root/b1-src bash 00-bootstrap.sh 처럼 덮어써서 쓴다.
# 이 lab 의 위치(=레포 루트)를 **실행 위치에서 계산**한다. 하드코딩하면 Multipass/클라우드 VM 처럼
# 레포가 다른 경로(/home/ubuntu/…)에 있는 환경에서 그대로 깨진다.
B1_LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export B1_LAB_DIR
export B1_REPO_ROOT="$(cd "$B1_LAB_DIR/../.." && pwd)"

# 제공 앱 원본을 받아둘 곳 (VM 에서는 /root/b1-src 등 원하는 곳으로 덮어써도 된다)
export LAB_SRC="${LAB_SRC:-$B1_REPO_ROOT/inputs}"
export B11_APP_SRC="$LAB_SRC/B1-1/agent-app-linux-x86"
# B1-2 는 x86-64 / AArch64 두 판이 있다 → 호스트 아키텍처로 고른다.
# (실측 e_machine: agent-leak-app-x86=0x3e00, agent-leak-app-arm64=0xb700.
#  B1-1 앱은 x86-64 판만 있으므로 ARM VM 에서는 B1-1 이 그대로 돌지 않는다.)
case "$(uname -m)" in
  aarch64|arm64) export B12_APP_SRC="$LAB_SRC/B1-2/agent-leak-app-arm64" ;;
  *)             export B12_APP_SRC="$LAB_SRC/B1-2/agent-leak-app-x86" ;;
esac

# B1-1 제출 monitor.sh(원본) 와 B1-2 프로세스 관제 스크립트 원본
export B11_MONITOR_SRC="$LAB_SRC/B1-1/monitor.sh"
export B12_PROCMON_SRC="$LAB_SRC/B1-2/vm/monitor.sh"
export B11_REPORT_SRC="$LAB_SRC/B1-1/report.sh"
