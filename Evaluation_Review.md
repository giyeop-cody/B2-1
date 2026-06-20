# 평가 항목 구현 검토

## 항목 1: 기능/요구사항 충족

- [x] add/list/search/summary/export/import/update/delete 정상 동작
- [x] 프로그램 재실행 후 데이터 유지 (3개 파일 이상)
- [x] category add/list/remove 정상 동작 (삭제 시 사용 중 카테고리 대체/방지)
- [x] budget set 저장 후 summary에서 예산 사용률/초과 여부 출력
- [x] import/export CSV 스키마 (UTF-8, 헤더, 컬럼) 준수
- [x] 잘못된 입력 시 스택트레이스 없이 오류 메시지 + 해결 힌트 출력
- [x] 오류 시 종료 코드 0 아님 (exit code 1)

## 항목 2: 구조/모듈화/안전성

- [x] 7개 모듈 + 6개 계층으로 분리, 각 모듈 책임 명확
- [x] 4개 이상 클래스 (Transaction, Budget, Category, ImportResult, SearchFilters, TransactionUseCase, BudgetUseCase, CategoryUseCase, ImportExportUseCase, JSONLTransactionRepository, JSONLCategoryRepository, JSONLBudgetRepository, ConsolePresenter, ConsoleView, CLIController)
- [x] 파일 기반 update/delete → rewrite_jsonl_atomic (임시 파일 + os.replace)로 안전 처리

## 항목 3: Generator / Decorator / Type Hint

- [x] list/search → yield 기반 스트리밍 (메모리 절약, 대용량 대응)
- [x] handle_app_errors (예외 처리) + timed (실행 시간) 데코레이터 2개 구현 및 적용
- [x] 전반적 타입 힌트 적용 + dataclass로 데이터 구조 명확화

## 항목 4: 포맷 선택 / 성능 / 데이터 신뢰성

- [x] JSONL vs CSV 장단점 비교 및 선택 근거 서술 (README.md)
- [x] 10만 건 대용량 시 병목 지점 (get_by_id, replace, delete 등 O(N) 순회) 및 개선 방안 인지
  - 개선 방안: id 기반 인덱스 파일 도입, categories 메모리 캐싱, SQLite 마이그레이션 고려
- [x] CSV import 부분 성공/롤백/리포트 구현
  - 행 단위 try-except로 실행. 실패 내역(행 번호+사유+원본 데이터) 수집 후 리포트.
  - 100% 실패 시 백업 파일로 롤백. 중간 성공 건은 유지.

## 항목 5: 보너스

- [x] 저장 원자성 강화 (rewrite_jsonl_atomic 임시 파일 + os.replace)
- [ ] 백업 기능 (backup 명령) - 미구현
- [ ] 반복 내역 기능 - 미구현
- [ ] 출력 포맷 테이블 정렬 - 미구현
