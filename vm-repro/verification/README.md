# 실제 검증 기록

2026-10-08 Asia/Seoul, 새 OrbStack 머신 `codyssey-b1-repro`, Ubuntu 24.04 amd64에서 실행했다. 기존 `b1-lab`은 재사용하지 않았다.

| 단계 | 증거 | 결과 |
|---|---|---|
| 새 VM B1-1 구성 | `b1-1-fresh.txt` | PASS=36 FAIL=0 |
| 같은 VM B1-2 전환 | `b1-1-to-b1-2.txt` | Agent READY, codyssey-b1-2 active, TCP 15034 |
| VM 재시작 | `b1-2-after-restart.txt` | B1-2 enabled/active, ssh/cron active, TCP 15034/20022 |
| 같은 VM B1-1 복원 | `b1-2-to-b1-1.txt` | PASS=36 FAIL=0 |
| 입력 및 셸 문법 검사 | `package-check.txt` | 모든 입력 SHA256/크기와 bash -n 통과 |
| 최종 setup 재실행 | `setup-repeat.txt` | 종료 코드 0, cron +2줄/125초, PASS=36 FAIL=0 |

최초 설치 중 래퍼의 cron 성공 문자열 검사 오류를 수정하고 `finalize`로 서비스를 등록했다. 최종 수정본은 `setup` 전체 재실행으로 종료 코드 0과 모든 검증 통과를 확인했다. 원본 설정 스크립트의 36개 검사와 cron 자체는 최초 실행부터 통과했다.

`reference-evidence/`는 이전 `b1-lab` 실험이고 위 새 VM 기록과 구분한다. 이 작업에서 장애 6개 장시간 실험을 다시 수행하지는 않았으며 기존 실행 파일과 명령을 보관했다.
