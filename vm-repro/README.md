# B1 VM 재현 패키지 (B2-1 보관)

기존 OrbStack B1-1 설정과 B1-2 전환/장애 실험 파일을 함께 보관한다. VM 디스크 스냅샷 없이 새 Ubuntu VM에서 같은 계정, 권한, SSH, 방화벽, 앱, 모니터링, cron, 로그 회전을 다시 만든다. B2-1 가계부 소스는 그대로 유지한다.

## Mac / OrbStack

OrbStack을 설치하고 실행한 뒤 이 저장소를 복제한다. 기존 `b1-lab`과 다른 `codyssey-b1-repro`를 생성한다.

```bash
git clone https://github.com/giyeop-cody/B2-1.git
cd B2-1
bash vm-repro/host/orbstack.sh setup
bash vm-repro/host/orbstack.sh switch
bash vm-repro/host/orbstack.sh restore
bash vm-repro/host/orbstack.sh verify
bash vm-repro/host/orbstack.sh export
```

`VM_NAME=my-lab bash vm-repro/host/orbstack.sh setup`으로 별도 VM을 만들 수 있다. Apple Silicon에서도 B1-1 원본이 x86 바이너리이므로 amd64 VM을 사용한다. 설치는 apt 다운로드와 cron 누적 125초를 포함한다.

## 다른 호스트 / 하이퍼바이저

Linux, Windows, 클라우드에서도 Ubuntu 24.04 **amd64** VM을 먼저 만든다. 권장 시작 자원은 2 vCPU, RAM 4GB, 디스크 20GB이다. 저장소를 VM의 `/root/codyssey-vm-repo` 등에 복사한 다음 VM 콘솔에서 실행한다.

```bash
sudo bash /root/codyssey-vm-repo/vm-repro/guest/lab.sh setup
sudo bash /root/codyssey-vm-repo/vm-repro/guest/lab.sh switch
sudo bash /root/codyssey-vm-repo/vm-repro/guest/lab.sh restore
```

설정 과정이 SSH를 재시작하고 포트를 20022로 변경하므로 최초 설치는 VM 콘솔에서 실행한다. root 원격 접속과 패스워드 인증은 차단된다. 클라우드 보안 그룹도 20022와 15034를 별도로 허용해야 한다. 외부 접속용 공개키는 설치 후 해당 계정에 등록한다. 이 패키지는 공유 SSH 개인키나 실제 API 키를 포함하지 않는다.

앱 입력은 모두 포함되어 GitHub의 최신 파일 변경과 무관하게 재현된다. OS 이미지와 apt 패키지 설치에는 인터넷이 필요하다. 재현 대상은 설정과 동작이며 OS 이미지의 바이트 동일성이나 ARM 네이티브 실행을 뜻하지 않는다. OrbStack에서는 Linux 커널을 공유하므로 커널/스케줄러 관측값은 호스트에 따라 달라진다.

## 파일 구성과 전환

| 경로 | 용도 |
|---|---|
| `inputs/manifest.json` | 원본 커밋, 파일 크기, SHA256; 설치 전 자동 검증 |
| `inputs/B1-1/` | 제공 앱, monitor.sh, report.sh 원본 |
| `inputs/B1-2/` | 제공 leak 앱과 프로세스 모니터 원본 |
| `B1-1/lab/scripts/` | 기존 계정/ACL/SSH/UFW/앱/cron/회전/36개 검증 스크립트 |
| `B1-2/lab/scripts/` | 같은 VM 전환, OOM/CPU/deadlock 전후 실험, 스케줄링 관측, 복원 |
| `guest/cloud-init.yaml` | 다른 하이퍼바이저에서 사용할 선택적 Ubuntu 초기 패키지 설정 |
| `guest/lab.sh` | Ubuntu 의존성 설치와 지속 실행 systemd 서비스 관리 |
| `host/orbstack.sh` | amd64 VM 생성, 파일 전송, 명령 실행, 증거 내보내기 |
| `reference-evidence/` | 기존 b1-lab에서 수집한 기록; 새 VM 결과와 구분 |
| `verification/` | 이 패키지로 새 VM을 만든 실제 검증 기록 |

`switch`는 같은 VM의 B1-1 앱을 중지하고 B1-2 바이너리/관제를 배치한다. 계정, 디렉터리, ACL, SSH, UFW, cron은 재사용한다. B1-2 서비스의 기본 설정은 MEMORY_LIMIT=512, CPU_MAX_OCCUPY=50, MULTI_THREAD_ENABLE=false다. `restore`는 B1-2를 중지하고 B1-1 앱을 다시 실행하여 36개 항목을 검증한다. 선택된 앱은 systemd에 등록되어 VM 재시작 후에도 실행된다.

모든 장애 전후 실험을 다시 실행하려면 `bash vm-repro/host/orbstack.sh experiments`를 실행한다. 각 시나리오는 기존 실행 시간 동안 PID, 타임스탬프, 앱 로그와 프로세스 관측을 수집하고 마지막에 B1-1로 복원한다. 결과는 VM의 `B1-2/lab/evidence/`에 생성되며 `export`로 호스트에 가져온다.

원래 스크립트의 실행 순서를 유지하고, 재현에 필요한 부분만 보완했다: 최신 Git clone 대신 포함된 입력과 해시 검증, 상대 경로 입력 기본값, 새 VM의 `/run/sshd` 생성, systemd 의존성/서비스 래퍼. 과거 샌드박스에 관한 스크립트 주석은 당시 기록이며 현재 실행 환경은 Ubuntu 24.04 VM이다.

패키지만 검사하려면 `python3 vm-repro/host/check-package.py`를 실행한다.

원본 `monitor.sh`는 일반 계정에서 `ufw status`를 실행하므로 권한 때문에 “Firewall is not active” 경고가 나올 수 있다. 실제 활성화는 root의 `ufw status verbose`와 `verify-all.sh`로 확인한다. 원본 입력은 수정하지 않았다.
