# 미션 설명 및 구현 검증

## 1. 미션 요구사항 요약

### 10가지 핵심 기능
1. add - 대화형 입력으로 거래 추가
2. list - 최신순 거래 목록 (제너레이터 스트리밍)
3. search - 날짜/카테고리/타입/메모/태그 조건 검색
4. summary - 월별 수입/지출/잔액 + TOP N + 예산 사용률/초과 경고
5. budget set - 월별 예산 설정
6. category add/list/remove - 카테고리 관리 (삭제 시 사용 중 처리)
7. update - 옵션 기반 거래 수정
8. delete - ID 기반 거래 삭제
9. import --from - CSV 가져오기 (부분 성공/롤백/리포트)
10. export --out - CSV보내기

### 저장 정책
- JSONL 또는 CSV 중 1개 선택
- 3개 이상 파일 분리 (transactions, categories, budgets)
- 기본 폴더 ./data, --data-dir 변경 가능
- 초기 실행 시 파일 자동 생성 또는 안내 메시지

### 기술 요구사항
- 데코레이터: 공통 예외/시간 처리 분리
- 예외 처리: 스택트레이스 없이 원인+힌트, 종료 코드 0 아님
- 모듈화: 3개 이상 모듈 분리
- dataclass + 타입 힌트
- Generator 스트리밍 (yield)
- CSV 스키마: date,type,category,amount,memo,tags (UTF-8, 헤더 포함)

## 2. 구현 대조 검증

| 요구사항 | 구현 상태 | 구현 위치 |
|----------|-----------|-----------|
| add (대화형) | ✅ | views/console_view.py prompt_transaction_input |
| list (최신순, --limit) | ✅ | usecases/transaction_usecase.py list_latest |
| search (조건) | ✅ | usecases/transaction_usecase.py search |
| summary (예산 연동) | ✅ | usecases/budget_usecase.py summarize |
| budget set | ✅ | usecases/budget_usecase.py set |
| category add/list/remove | ✅ | usecases/category_usecase.py |
| update (옵션 기반) | ✅ | usecases/transaction_usecase.py update |
| delete | ✅ | usecases/transaction_usecase.py delete |
| import --from | ✅ | usecases/import_export_usecase.py import_csv |
| export --out | ✅ | usecases/import_export_usecase.py export_csv |
| 3개 파일 분리 | ✅ | data/transactions.jsonl, categories.jsonl, budgets.jsonl |
| JSONL 선택 | ✅ | infrastructure/jsonl_storage.py |
| 초기 실행 안내 | ✅ | controllers/cli_controller.py build_controller |
| 데코레이터 | ✅ | decorators/error_handler.py, timer.py |
| 예외 처리 (스택트레이스 없음) | ✅ | decorators/error_handler.py handle_app_errors |
| 종료 코드 0 아님 | ✅ | return 1 in error_handler, SystemExit in __main__.py |
| 모듈 3개 이상 | ✅ | 10개 모듈, 6개 계층 |
| dataclass | ✅ | models/transaction.py, budget.py, category.py |
| 타입 힌트 | ✅ | 전체 코드 |
| Generator | ✅ | infrastructure/jsonl_storage.py iter_jsonl_reverse |
| CSV 스키마 | ✅ | import/export fieldnames 검증 |
