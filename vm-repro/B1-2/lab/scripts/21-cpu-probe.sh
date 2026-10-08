#!/usr/bin/env bash
# B1-2 CPU 시나리오 정밀 측정
# 실행: sudo bash 21-cpu-probe.sh <before|after> [관측초]
#
# 왜 필요한가: ps 의 %CPU 는 "프로세스 수명 전체 평균" 이라 순간 스파이크를 못 잡는다.
# 그래서 /proc/<pid>/stat 의 utime+stime 을 2초 간격으로 두 번 읽어 델타로 실측 CPU% 를 구하고,
# 같은 시각 앱이 스스로 보고하는 [CpuWorker] Current Load 와 나란히บันทึก한다.
set -uo pipefail
source "$(dirname "$0")/00-env.sh"
[[ $EUID -eq 0 ]] || { echo "root(sudo) 로 실행하세요"; exit 1; }

MODE="${1:?Usage: 21-cpu-probe.sh <before|after> [관측초]}"
OBS="${2:-90}"
case "$MODE" in
  before) CPU_MAX_OCCUPY=100 ;;
  after)  CPU_MAX_OCCUPY=50  ;;
  *) echo "unknown mode"; exit 1 ;;
esac

EV="$B12_LAB/evidence/cpu"
RUNDIR="$AGENT_LOG_DIR/b1-2/cpu-probe"
mkdir -p "$EV" "$RUNDIR"; chown "$AGENT_ADMIN:$GRP_CORE" "$RUNDIR"; chmod 775 "$RUNDIR"
APPLOG="$RUNDIR/app_${MODE}.log"
PROBE="$RUNDIR/cpu-probe_${MODE}.csv"
TXT="$EV/cpu-probe_${MODE}.txt"

pkill -f "$B12_APP" 2>/dev/null || true
sleep 2
: > "$APPLOG"; chown "$AGENT_ADMIN:$GRP_CORE" "$APPLOG"; chmod 664 "$APPLOG"

echo "== CPU probe ($MODE): MEMORY_LIMIT=512 CPU_MAX_OCCUPY=$CPU_MAX_OCCUPY MULTI_THREAD_ENABLE=false =="
runuser -u "$AGENT_ADMIN" -- bash -c "
  . '$AGENT_HOME/env.sh'
  export MEMORY_LIMIT=512 CPU_MAX_OCCUPY=$CPU_MAX_OCCUPY MULTI_THREAD_ENABLE=false
  setsid nohup '$B12_APP' >> '$APPLOG' 2>&1 < /dev/null &
"
for i in $(seq 1 20); do grep -q 'Agent READY' "$APPLOG" 2>/dev/null && break; sleep 1; done

PARENT="$(pgrep -f "$B12_APP" | head -1)"
WORKER="$(for p in $(pgrep -f "$B12_APP"); do echo "$(awk '/VmRSS/{print $2}' /proc/$p/status 2>/dev/null || echo 0) $p"; done | sort -rn | head -1 | awk '{print $2}')"
echo "parent=$PARENT worker=$WORKER"
{
  echo "case=cpu-$MODE"
  echo "timestamp=$(date '+%F %T')"
  echo "CPU_MAX_OCCUPY=$CPU_MAX_OCCUPY"
  echo "parent_pid=$PARENT worker_pid=$WORKER"
  echo "note=ps %CPU 는 수명 평균이라 스파이크를 못 잡음 → /proc/stat utime+stime 델타로 실측"
  echo
  echo "t,os_cpu_pct_worker,os_cpu_pct_parent,app_reported_load,worker_rss_kb"
} > "$PROBE"

ticks() { awk '{print $14+$15}' "/proc/$1/stat" 2>/dev/null || echo 0; }
HZ=$(getconf CLK_TCK)

{
echo "########## CPU PROBE $MODE (관측 ${OBS}s, HZ=$HZ) ##########"
echo "parent=$PARENT worker=$WORKER"
printf '%-10s %-14s %-14s %-14s %s\n' "t(s)" "OS_cpu_worker%" "OS_cpu_parent%" "app_load%" "worker_rss_kb"
} | tee "$TXT"

t0w=$(ticks "$WORKER"); t0p=$(ticks "$PARENT"); start=$(date +%s)
elapsed=0
while (( elapsed < OBS )); do
  sleep 2
  if ! kill -0 "$WORKER" 2>/dev/null; then
    now=$(date +%s); elapsed=$((now - start))
    echo ">>> 워커 프로세스 종료 @ ${elapsed}s (이후 행은 /proc 소멸로 측정 불가)" | tee -a "$TXT"
    break
  fi
  t1w=$(ticks "$WORKER"); t1p=$(ticks "$PARENT")
  cpuw=$(awk -v a="$t0w" -v b="$t1w" -v hz="$HZ" 'BEGIN{printf "%.1f", 100*(b-a)/(2*hz)}')
  cpup=$(awk -v a="$t0p" -v b="$t1p" -v hz="$HZ" 'BEGIN{printf "%.1f", 100*(b-a)/(2*hz)}')
  t0w=$t1w; t0p=$t1p
  load=$(grep -o 'Current Load: [0-9.]*%' "$APPLOG" 2>/dev/null | tail -1 | grep -o '[0-9.]*' || echo "-")
  rss=$(awk '/VmRSS/{print $2}' "/proc/$WORKER/status" 2>/dev/null || echo "-")
  now=$(date +%s); elapsed=$((now - start))
  printf '%-10s %-14s %-14s %-14s %s\n' "$elapsed" "$cpuw" "$cpup" "${load:--}" "$rss" | tee -a "$TXT"
  echo "$elapsed,$cpuw,$cpup,${load:--},$rss" >> "$PROBE"
  if ! kill -0 "$WORKER" 2>/dev/null; then
    echo ">>> 워커 프로세스 종료 @ ${elapsed}s" | tee -a "$TXT"
    break
  fi
done

{
echo
echo "-- top 배치 스냅샷 (2초 간격 2회) --"
top -b -n 2 -d 2 2>/dev/null | grep -E '^top|%Cpu|agent-leak' | tail -8
echo
echo "-- 앱 로그: Load / Threshold 관련 라인 --"
grep -E 'CpuWorker|CRITICAL' "$APPLOG" | tail -12
echo
echo "-- 앱 로그 마지막 6줄 --"
tail -6 "$APPLOG"
echo
if kill -0 "$WORKER" 2>/dev/null; then
  echo "result=SURVIVED_${OBS}s (관측 창 끝까지 생존 → 정리 kill)"
  kill -9 "$WORKER" "$PARENT" 2>/dev/null || true
else
  echo "result=TERMINATED @ ${elapsed}s"
fi
} | tee -a "$TXT"

cp -f "$APPLOG" "$EV/app_${MODE}-probe.log" 2>/dev/null || true
cp -f "$PROBE" "$EV/" 2>/dev/null || true
chown -R 1001:1001 "$EV" 2>/dev/null || true
echo "== PROBE DONE → $TXT =="
