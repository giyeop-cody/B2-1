# B1-2 lab — 공통 환경 상수
# B1-1 에서 구축한 "그 VM(=이 샌드박스)" 을 그대로 수정해서 쓴다.
# B1-1 lab 의 00-env.sh 를 그대로 source 하고 B1-2 전용 값만 덮어쓴다.

B12_LAB_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$B12_LAB_SELF/../../B1-1/lab/scripts/00-env.sh"

export B12_LAB="$B12_LAB_SELF"
export B12_APP="$AGENT_HOME/agent-leak-app"
export B12_PROCMON="$AGENT_HOME/bin/monitor-proc.sh"
export B12_STACKTRACE="$B12_LAB/scripts/capture-stacktrace.sh"
